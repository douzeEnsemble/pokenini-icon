# Dex-sheet-driven banner layers — design

**Repos touched:** `pokenini-api`, `pokenini-icon`. No changes to `pokenini-back` or `pokenini-web` — the existing trigger/status admin UI (see `2026-08-13-banner-generator-design.md` and the `2026-08-13-banner-pipeline-*` plans) is unaffected; it already just watches GitHub Actions/PR state, agnostic of where `generate.sh`'s config comes from.

## Context

`pokenini-icon`'s banner generator (`src/banner_generate/generate.sh`, shipped in the `banner-generator` branch / PR #39) currently reads its slug→layers mapping from a static, hand-edited `src/banner_generate/banners.json` committed in the repo. Maintaining that mapping by hand, disconnected from the actual Pokémon/dex data source, doesn't scale and drifts easily.

`pokenini-api` already owns Google Sheets ingestion for all Pokémon/dex data (`DexUpdater`, `src/Updater/DexUpdater.php`), syncing an `Dex` sheet tab into the `dex` table. That sheet tab already has a `Banner` column in its expected header (`DexUpdater.php:41`) — but it's read, validated, and discarded: it's never persisted. Investigation confirmed this existing column holds a visual preview (an `IMAGE()`-style formula), not structured data — unrelated to this feature, must not be reused or overwritten.

## Goal

The Dex sheet becomes the single source of truth for which dex/filter slugs get a generated banner, and what layers compose it. `pokenini-api` persists this per-dex-row and exposes it read-only. `pokenini-icon`'s generation workflow fetches it live at trigger time and only (re)generates banners that don't already exist locally. `banners.json` is retired.

## `pokenini-api` changes

### Migration
New column: `dex.banner_layers` — Postgres `text[]`, nullable. `NULL`/empty = no banner layers defined for this dex row (this dex is not part of banner generation).

### `DexUpdater`
- Add `'Banner Layers'` to `getExpectedHeader()` (a new, dedicated column — distinct from the existing unused `'Banner'` column, which stays untouched and still discarded as today).
- Sheet cell format: comma-separated layer names, e.g. `shiny,mega`. Empty cell → `NULL`.
- Parse and persist in `upsertRecord()`'s SQL alongside the existing fields.

### Auth: new scoped credential
The existing API auth is a single shared HTTP Basic credential (`web` user / `WEB_PASSWORD` env var, `ROLE_API`, `access_control: { path: ^/, roles: ROLE_API }` covering every route — see `config/packages/security.yaml`). No consumer scoping exists today; `pokenini-back` is the only consumer.

This feature adds the first non-`pokenini-back` consumer, so it gets its own restricted credential rather than reusing `WEB_PASSWORD`:
- New in-memory user `icon`, new role `ROLE_ICON`, new env var `ICON_API_PASSWORD`.
- New `access_control` entry restricting `ROLE_ICON` to only the new endpoint's path — this credential cannot call anything else in the API.

### New endpoint
`GET /istration/dex-banner-layers` (naming/path convention matches `ImagePipelineRunController`/`BannerPipelineRunController`'s `/istration/*` pattern). Accepts `ROLE_ICON` or `ROLE_API` — the existing shared credential must keep working everywhere it already does; `ROLE_ICON` only adds a narrower alternative, it doesn't take anything away from `ROLE_API`.

Response: `{ "<slug>": ["layer1", "layer2"], ... }` — only dex rows with non-empty `banner_layers`; rows with no layers are omitted entirely (never emitted as `[]`). This shape matches the retired `banners.json`'s shape exactly, so `pokenini-icon` needs no transformation.

Standard repo pattern: Controller (`src/Controller/`) → Service → Repository query → Response DTO + Factory (`src/DTO/Response/`, `src/Factory/`).

## `pokenini-icon` changes

### `generate.sh`
Add a skip check: for each slug, if `$destDir/$slug.png` already exists, skip regeneration (log `SKIP: <slug> already exists`, move to the next slug — not an error). The existing hard-fail-on-empty-array validation stays in place as defense in depth, even though the new API source never emits an empty array for an included slug.

### `update-banners.yml`
New step before `generate.sh` runs: `GET /istration/dex-banner-layers` (Basic auth with `icon` / a new `ICON_API_PASSWORD` GitHub secret in `pokenini-icon`, mirroring the env var name in `pokenini-api`; also needs a new `POKENINI_API_URL` GitHub secret/variable in `pokenini-icon`, since this is the first time this repo calls `pokenini-api` — no such secret exists here yet), write the JSON response to a temp file, point `BANNER_CONFIG_FILE` at it.

Guard against opening an empty PR: if the fetch returns `{}` (no dex has layers defined) or every slug is skipped as already-existing, the workflow must detect "no file changes" and skip the commit/PR-open steps entirely, rather than opening an empty PR.

### `banners.json` — retired
Deleted from the repo. `src/banner_generate/layers/*.png` (the actual layer artwork) is unaffected — still committed, still managed by hand / via `export_layers.sh` (see `src/banner/README.md`). Local, non-CI runs of `make banner_generate` without a config source are explicitly out of scope for this change — not a supported workflow going forward.

## Data flow (end to end)

1. Dex sheet sync in `pokenini-api` (admin action or cron) → `DexUpdater` persists `banner_layers` per dex row.
2. Admin clicks "Mettre à jour les bannières" in `pokenini-web` (existing button) → triggers `update-banners.yml` in `pokenini-icon` via `pokenini-back` (existing `TriggerBannersPipelineService`) — unchanged.
3. Workflow: fetch `GET /istration/dex-banner-layers` → run `generate.sh` against the fetched config, skipping any slug whose PNG already exists → (if anything changed) delete stale derivatives, commit, open PR `update-banners-<run-id>` — unchanged from the existing workflow except for the new fetch step and the empty-diff guard.
4. Unchanged: PR merge → `publish-images-to-resources.yml` (shared workflow) → PR to `pokenini-resources` (`sync-images-<merge-sha>`) → admin merges → banners live. `pokenini-web`'s existing status-polling UI is unaffected.

## Error handling / edge cases

- API call fails (network, auth, 5xx): workflow fails visibly at the fetch step; surfaced through the existing status-polling UI like any other workflow failure.
- Zero dex rows have layers defined (`{}` response), or every fetched slug is already generated locally: no file changes → no commit, no PR (explicit guard, see above).
- A slug is renamed/removed from the sheet after its banner was already generated: the old PNG becomes orphaned (never referenced by future fetches, never cleaned up automatically). Accepted as manual-cleanup territory — out of scope.
- Missing/wrong `ICON_API_PASSWORD`-equivalent secret in `pokenini-icon`: explicit 401 at the fetch step, easy to diagnose.

## Testing

- `pokenini-api`: extend the Dex sheet Moco fixture (`tests/resources/moco/Sheets/`) with the `Banner Layers` column — cases: multiple layers, single layer, empty cell. Unit + integration tests for `DexUpdater`'s new parsing and the new endpoint's controller/service/repository/factory. 100% coverage / 100% MSI, per repo standard.
- `pokenini-icon`: new scenario in `test_generate.sh` — pre-create a destination PNG for a slug, run `generate.sh`, assert it's untouched (mtime/content unchanged) and the log shows the `SKIP:` line.
- The workflow-level "no empty PR" guard is not unit-testable in isolation; verified manually / via a real PR run, same as the rest of the existing `update-banners.yml` workflow.
