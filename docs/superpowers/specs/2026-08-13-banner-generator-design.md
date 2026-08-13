# Banner generator + admin-triggered pipeline

## Context

Dex/filter banners (`images/dex/banner/`, 578×325, ~85 distinct banners ×
PNG+WebP) are currently produced entirely by hand: `src/banner/pokenini_banner.xcf`
is edited in GIMP, toggling which layers are visible, and each variant is
exported one at a time to `images/dex/banner/`. `src/banner_thumb/banner_thumb.sh`
(123px-wide thumbnails), `src/convert_png_webp/convert_png_webp.sh` (PNG→WebP),
and `src/check_size/check_size.sh` already run against whatever PNGs land
there — none of that needs to change.

Every banner is the same base composition with a different combination of
overlay layers switched on (confirmed: not text/color changes, and every
layer is exported at the full 578×325 canvas size — no per-layer
positioning to track). This is the same shape of problem the sprite
pipeline already solves (`pdb_dl`/`koenig_dl`/`placeholders` scripts,
wired into a `workflow_dispatch` GitHub Actions job, triggered from the
pokenini-web admin page — see `2026-07-14-update-images-pipeline-trigger-design.md`
and `2026-07-15-image-pipeline-status-tracking-design.md` in `pokenini-web`,
both authored against this same codebase).

GIMP itself is not installed on the dev host and manual `.xcf`
layer-toggling can't be scripted headlessly without it. This design moves
banner authoring to a "export each layer once, composite them
programmatically" model instead, using ImageMagick — already a project
dependency (`convert_png_webp.sh`, `banner_thumb.sh`) — rather than adding
a GIMP batch/Script-Fu dependency.

## Goal

1. A script in `pokenini-icon` that composites banner PNGs from a base
   image + named overlay layers, driven by a config file, replacing manual
   per-banner GIMP export.
2. An admin button on the pokenini-web admin page (`update_banners`,
   alongside the existing `update_images`) that triggers this
   remotely via GitHub Actions and opens a review PR, with status tracking
   — the full pattern already built for `update_images`, applied to
   banners as a second, independent pipeline.

## Non-goals (explicitly out of scope for this iteration)

- Migrating the ~85 existing banners' layer composition into the new
  config. That requires re-exporting each layer out of the existing
  `.xcf` by hand (a one-time content task, not a coding task) and is done
  after this tooling exists, not as part of it.
- Any change to `publish-images-to-resources.yml` — it already triggers
  on `push` to `main` under `paths: images/**`, which covers
  `images/dex/banner/**` with zero modification (see "Overall flow").
- Generalizing `ImagePipelineRun`/its surrounding services into a
  multi-type pipeline (`pipelineType` discriminator, data-driven Twig
  partials). A second, duplicated vertical slice (`BannerPipelineRun` and
  siblings) is used instead — consistent with this codebase's existing
  precedent of introducing a new entity rather than stretching an
  existing one to a shape it wasn't designed for (`ActionLog` vs.
  `ImagePipelineRun`), and it keeps the well-tested `update_images` path
  completely untouched.
- Per-layer positioning/cropping — every layer is a full 578×325 canvas
  export with transparency, composited at (0,0).
- Live progress UI beyond what `update_images` already has (still
  click-to-refresh, no auto-polling JS, no run history — only the latest
  run per pipeline is tracked).

## Design

### Overall flow

```
pokenini-web (admin button "update_banners")
  → pokenini-back (POST /istration/action/trigger/update_banners)
      → GitHub API: POST /repos/{owner}/pokenini-icon/actions/workflows/update-banners.yml/dispatches
          → Workflow A runs in pokenini-icon (workflow_dispatch):
              make banner_generate   (new — composites PNGs from config)
              make img_convert       (existing, already generic)
              make banner_thumb      (existing, already generic)
              make check_size        (existing, output captured, non-blocking)
              commit changed files under images/dex/banner, images/dex/thumbs
              to a new branch, open a PR against pokenini-icon's main

  [review & merge that PR — the risk checkpoint, same as update_images]

          → Workflow B: publish-images-to-resources.yml — UNCHANGED, fires
            automatically on push to main under images/** (already covers
            images/dex/banner/)
              → PR against pokenini-resources, reviewed/merged as today
```

pokenini-back polls status the same way it does for `update_images`:
Workflow A run (matched by `run-name`/`correlation_id`) → icon-repo PR
(branch `update-banners-<run id>`) → Workflow B run (matched by
`head_sha` == icon PR's merge commit) → resources-repo PR (branch
`sync-images-<head_sha>`, from the existing, unmodified Workflow B).

### pokenini-icon — banner generation

New `src/banner_generate/`:

```
src/banner_generate/
  base.png              # background canvas, 578×325
  layers/
    <layer-name>.png     # one overlay per named layer, 578×325, transparent
    ...
  banners.json           # slug -> ordered list of layer names
  generate.sh
  test_generate.sh       # bash test script, same PASS/FAIL convention as test_banner_thumb.sh
```

`banners.json` — flat map, seeded with the ~85 slugs already present in
`images/dex/banner/` (layer lists populated by hand afterward, per
"Non-goals" above):

```json
{
  "blackwhite": ["logo-blackwhite"],
  "alpha": ["logo-alpha", "shiny-badge"]
}
```

`generate.sh`: for each `slug => [layer, ...]` entry, run
`convert base.png layers/<layer1>.png -composite layers/<layer2>.png -composite ... images/dex/banner/<slug>.png`.
Fails loudly (non-zero exit, clear message naming the missing file) if a
referenced layer PNG doesn't exist under `layers/`. Concurrency follows
`banner_thumb.sh`'s existing `xargs -P $(nproc)` pattern.

**Makefile**: new target `banner_generate: bash src/banner_generate/generate.sh`,
same style as `pdb_dl`/`koenig_dl`. No change to `img_convert`,
`banner_thumb`, or `check_size` — all three already operate generically
over `images/`.

### pokenini-icon — Workflow A

New `.github/workflows/update-banners.yml`, mirroring
`update-images.yml`'s shape exactly:

```yaml
on:
  workflow_dispatch:
    inputs:
      correlation_id:
        required: true
        type: string

run-name: "Update banners (${{ inputs.correlation_id }})"

permissions:
  contents: write
  pull-requests: write
```

Steps: checkout → `apt-get install imagemagick webp` → `make banner_generate`
→ `make img_convert` → `make banner_thumb` → `make check_size | tee check_size_report.txt`
(never fails the job) → if `images/dex/banner` or `images/dex/thumbs`
changed, open a PR via `peter-evans/create-pull-request@v7`
(`branch: update-banners-${{ github.run_id }}`,
`add-paths: images/dex/banner, images/dex/thumbs`,
`body-path: check_size_report.txt`, `delete-branch: true`); if nothing
changed, no PR — normal, non-error outcome. Uses the default
`GITHUB_TOKEN`, same as Workflow A for images (job only touches its own
repo).

No change to `publish-images-to-resources.yml` or its `RESOURCES_PUSH_TOKEN`.

### pokenini-api — `BannerPipelineRun`

New entity `src/Entity/ImagePipelineRun.php`'s twin — same shape, same
`BaseEntityTrait`, same 14 fields
(`correlationId`, `createdAt`, `updatedAt`,
`workflowARunId`/`workflowAStatus`/`workflowAConclusion`/`workflowAUrl`,
`iconPrNumber`/`iconPrUrl`/`iconPrState`/`iconPrMergeCommitSha`,
`workflowBRunId`/`workflowBStatus`/`workflowBConclusion`/`workflowBUrl`,
`resourcesPrNumber`/`resourcesPrUrl`/`resourcesPrState`), own migration.

New `src/Controller/BannerPipelineRunController.php`, deliberately
duplicated rather than parameterizing `ImagePipelineRunController`:
`#[Route('/istration/banner-pipeline-runs')]` with the same 3 verbs
(`POST ''` create, `PATCH '/{correlationId}'` partial update,
`GET '/latest'`), same `*ResponseFactory`/`*Response` DTO pattern
(`BannerPipelineRunResponseFactory`/`BannerPipelineRunResponse`).

### pokenini-back

Reused as-is (already generic — take a repo/workflow-file/token as
config, not hardcoded to images): `GithubActionsApiService`,
`GithubQueryApiService`. New config values:
`GITHUB_BANNERS_WORKFLOW_FILE=update-banners.yml`,
`GITHUB_BANNERS_WORKFLOW_B_FILE=publish-images-to-resources.yml` — same
repo (`pokenini-icon`) and same `GITHUB_IMAGES_WORKFLOW_TOKEN` as the
images pipeline, since both workflows live in the same repo; no new PAT
needed.

New, duplicated from the images-pipeline pattern:

- `src/Service/TriggerBannersPipelineService.php` (twin of
  `TriggerImagesPipelineService`) — generates a correlation id, calls
  `GithubActionsApiService::dispatchWorkflow()` against the banners
  workflow config, then `BannerPipelineApiService::create()`.
- `src/Service/Api/BannerPipelineApiService.php` (twin of
  `ImagePipelineApiService`) — points at
  `/istration/banner-pipeline-runs` on pokenini-api.
- `src/Controller/Admin/AdminActionTriggerController.php`: extend the
  existing `condition: "params['name'] in ['update_images', 'update_banners']"`
  and dispatch to the right trigger service by name — same standalone
  controller (not `AbstractAdminActionController`), same reasoning as
  `update_images` (no `CacheInvalidatorService` entry makes sense here).
- `src/Service/BannerPipelineStatusService.php` (twin of
  `ImagePipelineStatusService`) — identical poll-one-not-yet-final-stage
  reconciliation logic, reading/writing `BannerPipelineRun` via
  `BannerPipelineApiService` instead.
- `src/Controller/Admin/BannerPipelineStatusController.php`:
  `GET /istration/action/trigger/update_banners/status`, same `refresh`
  query-param convention as `ImagePipelineStatusController`.

### pokenini-web

- `AdminActionController::trigger()`: extend the condition list to
  `['update_images', 'update_banners']` — `AdminActionService::execute()`
  needs no change (already generic `POST /istration/action/{action}/{item}`).
- `_trigger_pipeline.html.twig`: extend the existing data-driven map —
  `{ 'update_images': 'images', 'update_banners': 'image' }` — plus new
  translation keys
  `admin.actions.trigger_pipeline.update_banners.{title,description,cta}`.
- New `src/Service/GetBannerPipelineStatusService.php` (twin of
  `GetImagePipelineStatusService`), pointing at
  `/istration/action/trigger/update_banners/status`.
- New `templates/Admin/_banner_pipeline_status.html.twig`, a duplicate of
  `_pipeline_status.html.twig` (which is hardcoded to the 4 images-pipeline
  stage names) rendered under its own "Banners" section — same
  idle/running/done/failed badge vocabulary, own "Refresh status" link.
- `AdminTriggerPipelineController`: also fetch banner status via the new
  service and pass it to the template alongside the existing image
  pipeline status.

## Error handling

Same rules as the images pipeline, applied per-pipeline (a banners
failure never affects images status or vice versa, since they're fully
separate entities/services):

- Dispatch failures (bad/expired token, workflow renamed, GitHub API
  outage) surface as `ko` through the existing `AdminAction`/flash-message
  machinery.
- If `pokenini-api` is unreachable when persisting a new
  `BannerPipelineRun` or a poll update, the trigger itself still succeeds
  (dispatch already happened) — log the persistence failure, degrade to
  "status unknown."
- `check_size.sh` never exits non-zero — dimension mismatches are
  informational only, never fail the job.
- No changes since the last run → Workflow A completes without opening a
  PR (normal outcome), and Workflow B never fires.
- `generate.sh` failing on a missing layer file *does* fail the GitHub
  Actions job (unlike `check_size`) — a broken banner config should block
  the PR, not silently produce a wrong or missing banner.
- Success means "GitHub accepted the dispatch" / "the last known
  polled snapshot," never "banners are live" — same wording discipline as
  `update_images`.

## Testing

- **pokenini-icon**: `test_generate.sh` (bash, PASS/FAIL, same style as
  `test_banner_thumb.sh`) covering: correct composite for a
  single-layer banner, correct composite for a multi-layer banner,
  missing-layer failure, empty config. Workflow A validated by one real
  `gh workflow run update-banners.yml` end-to-end run, matching how
  `update-images.yml` was validated — no CI-for-CI tests.
- **pokenini-api**: unit-test `BannerPipelineRunController`/its
  service/repository against a real test database, mirroring
  `ImagePipelineRun`'s existing test suite structure.
- **pokenini-back**: unit-test `TriggerBannersPipelineService`,
  `BannerPipelineApiService`, `BannerPipelineStatusService`, and both new
  controllers, mirroring the existing `*Images*` test suites (mocked
  `HttpClientInterface`, mocked pokenini-api client). Must keep the
  project's 100% coverage / 100% MSI bar.
- **pokenini-web**: unit-test the extended `trigger()` condition and the
  new `GetBannerPipelineStatusService`; template-rendering tests for
  `_banner_pipeline_status.html.twig` across each stage-state
  combination; Moco-backed integration test for the new status endpoint's
  happy path, matching `ActionTriggerTest`'s conventions.
