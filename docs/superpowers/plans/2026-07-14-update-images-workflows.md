# Update-images GitHub Actions Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the existing (unmodified) `pokenini-icon` image pipeline be triggered remotely via `workflow_dispatch`, land its output as a reviewable PR against this repo, and automatically chain a second PR into `pokenini-resources` once that first PR is merged.

**Architecture:** Two GitHub Actions workflows in this repo. Workflow A (`update-images.yml`, `workflow_dispatch`-triggered) runs the existing Makefile targets and opens a PR against `pokenini-icon`'s own `main` with whatever changed under `images/`. Workflow B (`publish-images-to-resources.yml`, triggered by `push` to `main` under `images/**`) checks out `pokenini-resources` as a sibling directory, runs its existing `make copy`, and opens a PR there.

**Tech Stack:** GitHub Actions (`ubuntu-latest` runners), the existing bash/Python/Docker scripts under `src/`, `peter-evans/create-pull-request` for PR creation.

## Global Constraints

- Do not modify any existing script under `src/download-from-pokemon-db/`, `src/cut-mbcmechachu-sprites/`, `src/placeholders/`, or `src/check_size/` — the workflows call the existing `Makefile` targets unchanged (see design spec, "Non-goals").
- Workflow A must never publish directly — it only opens a PR against `pokenini-icon`'s own `main`, for human review of mis-detected sprites (see spec, "Non-goals" and "Goal").
- Workflow B must only run after a merge to `main` touches `images/**`, never against an unmerged branch (see spec, "Two chained workflows" / avoiding the ordering problem).
- Companion spec: `../pokenini-web/docs/superpowers/specs/2026-07-14-update-images-pipeline-trigger-design.md` (this workspace's shared spec; lives in the `pokenini-web` repo since that's where the admin button was designed).

---

### Task 1: Workflow A — trigger the pipeline and open a PR against pokenini-icon

**Files:**
- Create: `.github/workflows/update-images.yml`

**Interfaces:**
- Produces: a `workflow_dispatch`-triggered GitHub Actions workflow named `update-images.yml` in this repo, callable via `POST /repos/douzeensemble/pokenini-icon/actions/workflows/update-images.yml/dispatches` — this exact path is what the `pokenini-back` plan's `GithubActionsApiService` will call.

- [ ] **Step 1: Write the workflow file**

```yaml
name: Update Pokémon images

on:
  workflow_dispatch: {}

jobs:
  update-images:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Checkout pokenini-icon
        uses: actions/checkout@v5

      - name: Install image tooling
        run: sudo apt-get update && sudo apt-get install -y imagemagick webp

      - name: Download, convert and copy "big" sprites from pokemondb.net
        run: |
          make pdb_dl
          make pdb_convert
          make pdb_copy

      - name: Cut and copy "small" sprites from the static spritesheet
        run: |
          make mbc_prepare
          make mbc_cut
          make mbc_copy

      - name: Fill in missing shiny placeholders
        run: make placeholders

      - name: Check image dimensions
        run: make check_size | tee check_size_report.txt

      - name: Open a PR with any changed images
        uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "Update Pokémon images"
          branch: update-images-${{ github.run_id }}
          title: "Update Pokémon images"
          body-path: check_size_report.txt
          add-paths: images
          delete-branch: true
```

- [ ] **Step 2: Validate the YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/update-images.yml'))" && echo VALID`
Expected: `VALID` printed, no exception.

- [ ] **Step 3: Validate the job structure**

Run:
```bash
python3 -c "
import yaml
doc = yaml.safe_load(open('.github/workflows/update-images.yml'))
assert True in doc or 'on' in doc, 'missing on: trigger'
trigger_key = True if True in doc else 'on'
assert 'workflow_dispatch' in doc[trigger_key], 'not workflow_dispatch-triggered'
job = doc['jobs']['update-images']
assert job['runs-on'] == 'ubuntu-latest'
step_names = [s['name'] for s in job['steps']]
assert step_names == [
    'Checkout pokenini-icon',
    'Install image tooling',
    'Download, convert and copy \"big\" sprites from pokemondb.net',
    'Cut and copy \"small\" sprites from the static spritesheet',
    'Fill in missing shiny placeholders',
    'Check image dimensions',
    'Open a PR with any changed images',
]
print('STRUCTURE OK')
"
```
Expected: `STRUCTURE OK` printed, no `AssertionError`.

(Note: PyYAML parses the unquoted `on:` key as the boolean `True`, hence
the `True in doc` check above — this is a known YAML 1.1 quirk, not a
mistake in the workflow file itself, which is written the same way every
other GitHub Actions workflow in this org is written.)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/update-images.yml
git commit -m "Add workflow_dispatch pipeline to regenerate Pokémon images"
```

---

### Task 2: Workflow B — publish merged images to pokenini-resources

**Files:**
- Create: `.github/workflows/publish-images-to-resources.yml`

**Interfaces:**
- Consumes: the `RESOURCES_PUSH_TOKEN` repository secret (configured manually in Task 3 — this task's workflow references it but it won't function end-to-end until that secret exists).
- Produces: a `push`-triggered workflow (path filter `images/**` on `main`) that opens a PR against `douzeensemble/pokenini-resources`.

- [ ] **Step 1: Write the workflow file**

```yaml
name: Publish images to pokenini-resources

on:
  push:
    branches: [main]
    paths:
      - 'images/**'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout pokenini-icon
        uses: actions/checkout@v5
        with:
          path: pokenini-icon

      - name: Checkout pokenini-resources
        uses: actions/checkout@v5
        with:
          repository: douzeensemble/pokenini-resources
          token: ${{ secrets.RESOURCES_PUSH_TOKEN }}
          path: pokenini-resources

      - name: Sync images into pokenini-resources
        working-directory: pokenini-resources
        run: make copy

      - name: Open a PR on pokenini-resources with the synced images
        uses: peter-evans/create-pull-request@v7
        with:
          token: ${{ secrets.RESOURCES_PUSH_TOKEN }}
          path: pokenini-resources
          commit-message: "Sync images from pokenini-icon@${{ github.sha }}"
          branch: sync-images-${{ github.sha }}
          title: "Sync images from pokenini-icon@${{ github.sha }}"
          delete-branch: true
```

- [ ] **Step 2: Validate the YAML parses**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/publish-images-to-resources.yml'))" && echo VALID`
Expected: `VALID` printed, no exception.

- [ ] **Step 3: Validate the trigger and step structure**

Run:
```bash
python3 -c "
import yaml
doc = yaml.safe_load(open('.github/workflows/publish-images-to-resources.yml'))
trigger_key = True if True in doc else 'on'
push_cfg = doc[trigger_key]['push']
assert push_cfg['branches'] == ['main']
assert push_cfg['paths'] == ['images/**']
job = doc['jobs']['publish']
step_names = [s['name'] for s in job['steps']]
assert step_names == [
    'Checkout pokenini-icon',
    'Checkout pokenini-resources',
    'Sync images into pokenini-resources',
    'Open a PR on pokenini-resources with the synced images',
]
print('STRUCTURE OK')
"
```
Expected: `STRUCTURE OK` printed, no `AssertionError`.

- [ ] **Step 4: Verify the sibling-checkout paths match `pokenini-resources`'s `make copy` assumption**

`pokenini-resources`'s `Makefile` target `copy` runs `cp -R ../pokenini-icon/images/* .` — it assumes `pokenini-icon` is a sibling directory one level up. Confirm the checkout `path:` values above (`pokenini-icon`, `pokenini-resources`) produce exactly that layout under `$GITHUB_WORKSPACE`:

Run: `test -f ../pokenini-resources/Makefile && grep -n "cp -R ../pokenini-icon/images" ../pokenini-resources/Makefile`
Expected: prints the `copy:` line, confirming the relative path assumption this workflow relies on (no change needed to `pokenini-resources`).

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/publish-images-to-resources.yml
git commit -m "Add workflow to publish merged image changes to pokenini-resources"
```

---

### Task 3: Configure the `RESOURCES_PUSH_TOKEN` secret (manual, not scripted)

This step needs a real GitHub token value from your own account and cannot be scripted by an agent.

- [ ] **Step 1: Create a fine-grained personal access token**

In GitHub Settings → Developer settings → Fine-grained tokens, create a token scoped **only** to the `douzeensemble/pokenini-resources` repository, with repository permissions `Contents: Read and write` and `Pull requests: Read and write`. No other scopes.

- [ ] **Step 2: Store it as a repository secret on `pokenini-icon`**

Run (replace `<paste-token>` with the value from Step 1 — do not commit it anywhere):

```bash
gh secret set RESOURCES_PUSH_TOKEN --repo douzeensemble/pokenini-icon --body "<paste-token>"
```

Expected: `✓ Set Actions secret RESOURCES_PUSH_TOKEN for douzeensemble/pokenini-icon`

- [ ] **Step 3: Confirm it's set (without revealing the value)**

Run: `gh secret list --repo douzeensemble/pokenini-icon`
Expected: `RESOURCES_PUSH_TOKEN` appears in the list.

---

### Task 4: End-to-end validation against the real repos

This is the closest thing to a "test" this plan has — there's no existing automated-test convention for the Makefile/workflow layer in this repo (see spec, "Testing"). Do this after Tasks 1–3 are merged to `main` (workflows only run off `main` by default for `workflow_dispatch`, and Workflow B is triggered by pushes to `main`).

- [ ] **Step 1: Merge this branch, then manually trigger Workflow A**

```bash
gh workflow run update-images.yml --repo douzeensemble/pokenini-icon
```
Expected: no error output (the command queues the run; it doesn't print a run URL directly).

- [ ] **Step 2: Watch the run and confirm it succeeds**

```bash
gh run list --repo douzeensemble/pokenini-icon --workflow update-images.yml --limit 1
gh run watch --repo douzeensemble/pokenini-icon $(gh run list --repo douzeensemble/pokenini-icon --workflow update-images.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```
Expected: run completes with status `completed` / conclusion `success`.

- [ ] **Step 3: Confirm a PR was opened against pokenini-icon (assuming the pipeline found changes)**

```bash
gh pr list --repo douzeensemble/pokenini-icon --state open
```
Expected: a PR titled "Update Pokémon images" is listed (or, if `pokemons-list.txt`/spritesheets hadn't changed since the last run, no PR — also a valid, expected outcome per the spec).

- [ ] **Step 4: Merge that PR, then confirm Workflow B fired and opened the follow-up PR**

```bash
gh pr merge <pr-number> --repo douzeensemble/pokenini-icon --merge
gh run list --repo douzeensemble/pokenini-icon --workflow publish-images-to-resources.yml --limit 1
gh pr list --repo douzeensemble/pokenini-resources --state open
```
Expected: Workflow B run shows `success`, and a PR titled "Sync images from pokenini-icon@<sha>" is open on `pokenini-resources`.

- [ ] **Step 5: Leave both PRs for human review**

Do not merge the `pokenini-resources` PR as part of this validation — that final review/merge/release step stays manual, exactly as before this feature (see spec, "Overall flow": "Merging the `pokenini-resources` PR and cutting a release there stays exactly as it is today").
