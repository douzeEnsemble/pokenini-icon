# Dex-Sheet-Driven Banner Generation (pokenini-icon) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `generate.sh` skips banners whose PNG already exists locally, and `update-banners.yml` fetches its slug→layers config from a new `pokenini-api` endpoint instead of a committed `banners.json`, which is retired.

**Architecture:** `generate_one()` in `generate.sh` gains an early return when the destination file already exists, tracked via a second done-file-style counter so the summary line reports skips separately. `update-banners.yml` gains a `curl` step (Basic auth against a new scoped `pokenini-api` credential) that writes the fetched JSON to `$RUNNER_TEMP`, which both the generation step and the stale-derivative-cleanup step then read instead of the deleted `banners.json`.

**Tech Stack:** Bash, ImageMagick (`convert`/`identify`), `jq`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-16-dex-sheet-banner-layers-design.md`

**Base branch note for whoever executes this plan:** this work modifies `generate.sh`, `Makefile`, `banners.json`, and `update-banners.yml` — all introduced by the still-open `banner-generator` branch (PR #39). Check whether PR #39 has merged to `main` before creating a worktree: if merged, branch from `main`; if not, branch from `banner-generator` (stacked) and say so explicitly when opening this plan's PR, since it'll need PR #39 merged first before it can itself merge cleanly. Task 2 Step 4's README text also references `src/banner/export_layers.sh` — a working, tested script written during this session's exploration but not yet committed anywhere as of this plan's writing; confirm it exists on whatever branch you're building on (it should land via PR #39 or be added alongside it) before treating that README reference as accurate.

## Global Constraints

- `set -euo pipefail` in all bash scripts (already the case in `generate.sh`/`test_generate.sh` — preserve it).
- No behavior change to any existing `test_generate.sh` scenario (1-9) — the new skip logic must be additive; run the full existing suite after every step.
- The new `curl` fetch step must fail loudly (non-2xx / network error) rather than silently proceeding with no config — `curl -sf` (fail-on-HTTP-error) achieves this; do not swallow its exit code.
- Endpoint contract (from the spec / the paired `pokenini-api` plan): `GET /istration/dex-banner-layers`, HTTP Basic auth (`icon` / `ICON_API_PASSWORD`), response body is a JSON object `{ "<slug>": ["layer1", "layer2"], ... }` — rows with no layers are omitted entirely, never emitted as `[]`. This is exactly `generate.sh`'s existing `BANNER_CONFIG_FILE` shape, so no transformation is needed between the fetched response and the file `generate.sh` reads.

---

### Task 1: `generate.sh` skips banners whose output already exists

**Files:**
- Modify: `src/banner_generate/generate.sh`
- Test: `src/banner_generate/test_generate.sh`

**Interfaces:**
- Produces: `generate_one()` now checks `$destinationFile` for existence before doing any work. The final summary line format changes from `Generated %d of %d banners\n` to `Generated %d of %d banners (%d already existed, skipped)\n` — every existing `assert_matches` call in `test_generate.sh` that checks this line uses an unanchored substring pattern (e.g. `"Generated 3 of 3 banners"`), so the added suffix does not break any of them; verify this in Step 2 below rather than assuming it.

- [ ] **Step 1: Write the failing test**

Add to `src/banner_generate/test_generate.sh`, after Scenario 9 (before the `if [ "$failures" -ne 0 ]; then` block at the end):

```bash
# Scenario 10: a slug whose output PNG already exists is skipped entirely
# (not regenerated) -- this lets a run avoid re-doing work for banners
# that haven't changed since the last run.
dir10="$workdir/dir10"
mkdir -p "$dir10/layers" "$dir10/out"
convert -size 578x325 xc:red PNG32:"$dir10/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir10/layers/logoA.png"
cat > "$dir10/banners.json" <<'JSON'
{
  "existing": ["logoA"]
}
JSON
dest10="$dir10/out"
# Pre-create the output as something the real composite would NOT produce
# (solid green, not red+blue), so "untouched" is provable, not coincidental.
convert -size 578x325 xc:green PNG32:"$dest10/existing.png"
preHash=$(md5sum "$dest10/existing.png" | awk '{print $1}')

output10=$(BANNER_BASE_IMAGE="$dir10/base.png" BANNER_LAYERS_DIR="$dir10/layers" BANNER_CONFIG_FILE="$dir10/banners.json" bash "$SCRIPT" "$dest10" 2>&1)
postHash=$(md5sum "$dest10/existing.png" | awk '{print $1}')

assert_equals "existing banner file is left byte-for-byte untouched" "$preHash" "$postHash"
assert_matches "skip is logged for the existing banner" "SKIP: existing already exists" "$output10"
assert_matches "summary reports 0 generated, 1 skipped" "Generated 0 of 1 banners \(1 already existed, skipped\)" "$output10"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash src/banner_generate/test_generate.sh`
Expected: Scenario 10's three new assertions FAIL (the skip logic doesn't exist yet, so `existing.png` gets overwritten with the real composite, the SKIP log line never appears, and the summary line still reads the old un-suffixed format). Confirm Scenarios 1-9 still PASS — this proves the summary-line format change (once made) is additive and doesn't need every existing assertion rewritten. Note: at this point in Step 2 the summary format hasn't changed yet, so scenarios 1-9 pass trivially; the real regression check happens in Step 4 after the implementation.

- [ ] **Step 3: Implement the skip logic**

In `src/banner_generate/generate.sh`, find this block (currently right before `generate_one()`'s definition):

```bash
DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT
```

Replace with:

```bash
DONE_FILE=$(mktemp)
SKIP_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE" "$SKIP_FILE"' EXIT
```

Find `generate_one()`'s body:

```bash
generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile

    while IFS= read -r layer; do
```

Replace with (adds the skip check right after `destinationFile` is computed, before any layer work happens):

```bash
generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile

    if [ -f "$destinationFile" ]; then
        printf "SKIP: %s already exists: %s\n" "$slug" "$destinationFile"
        printf "SKIP\n" >> "$SKIP_FILE"
        return 0
    fi

    while IFS= read -r layer; do
```

Find the `export` line right after `generate_one`'s closing brace:

```bash
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE DONE_FILE
```

Replace with:

```bash
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE DONE_FILE SKIP_FILE
```

Find the summary block at the end of the file:

```bash
iDone=$(wc -l < "$DONE_FILE")
printf "Generated %d of %d banners\n" "$iDone" "${#slugs[@]}"
```

Replace with:

```bash
iDone=$(wc -l < "$DONE_FILE")
iSkip=$(wc -l < "$SKIP_FILE")
printf "Generated %d of %d banners (%d already existed, skipped)\n" "$iDone" "${#slugs[@]}" "$iSkip"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash src/banner_generate/test_generate.sh`
Expected: `All assertions passed`, all 10 scenarios green, including the pre-existing ones (1-9) — confirming their unanchored `assert_matches` patterns tolerate the new `(N already existed, skipped)` suffix.

- [ ] **Step 5: Commit**

```bash
git add src/banner_generate/generate.sh src/banner_generate/test_generate.sh
git commit -m "feat: skip regenerating banners whose output already exists"
```

---

### Task 2: retire `banners.json`, fetch config from `pokenini-api` in CI

**Files:**
- Delete: `src/banner_generate/banners.json`
- Modify: `.github/workflows/update-banners.yml`
- Modify: `Makefile`
- Modify: `README.md`

**Interfaces:**
- Consumes: `GET /istration/dex-banner-layers` from `pokenini-api` (see the paired `pokenini-api` plan / the design spec) — HTTP Basic auth, response body `{ "<slug>": ["layer1", ...], ... }`.
- Consumes (new, must be configured as real GitHub Actions secrets in this repo before the workflow can run for real — cannot be done via a PR, flag this to whoever merges): `secrets.POKENINI_API_URL` (the `pokenini-api` base URL, e.g. `https://api.pokenini.example`), `secrets.ICON_API_PASSWORD` (the `icon` user's password, matching `pokenini-api`'s `ICON_API_PASSWORD` env var).

No automated test covers this task (workflow YAML isn't unit-testable, and there's no local `pokenini-api` to hit in CI for this repo) — verification is: `jq` validates the new/edited YAML's embedded scripts don't have shell syntax errors (Step 2 below), and real confirmation happens when the workflow is manually triggered post-merge (already how `update-banners.yml`'s existing steps are verified, per the design spec's Testing section).

- [ ] **Step 1: Delete the static config and update the workflow**

```bash
git rm src/banner_generate/banners.json
```

Replace the full content of `.github/workflows/update-banners.yml` with:

```yaml
name: Update banners

on:
  workflow_dispatch:
    inputs:
      correlation_id:
        required: true
        type: string

run-name: "Update banners (${{ inputs.correlation_id }})"

jobs:
  update-banners:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Checkout pokenini-icon
        uses: actions/checkout@v5

      - name: Install image tooling
        run: sudo apt-get update && sudo apt-get install -y imagemagick webp jq

      - name: Fetch dex banner-layers config from pokenini-api
        env:
          POKENINI_API_URL: ${{ secrets.POKENINI_API_URL }}
          ICON_API_PASSWORD: ${{ secrets.ICON_API_PASSWORD }}
        run: |
          curl -sf -u "icon:$ICON_API_PASSWORD" \
            "$POKENINI_API_URL/istration/dex-banner-layers" \
            -o "$RUNNER_TEMP/dex-banner-layers.json"

      - name: Generate banner PNGs from base + layers
        env:
          BANNER_CONFIG_FILE: ${{ runner.temp }}/dex-banner-layers.json
        run: make banner_generate

      - name: Remove stale .webp/thumbnail for regenerated banners
        run: |
          jq -r 'keys[]' "$RUNNER_TEMP/dex-banner-layers.json" | while IFS= read -r slug; do
            rm -f "images/dex/banner/$slug.webp" "images/dex/thumbs/$slug.png"
          done

      - name: Convert all .png images to .webp
        run: make img_convert

      - name: Generate banner thumbnails
        run: make banner_thumb

      - name: Check image dimensions
        run: make check_size | tee check_size_report.txt

      - name: Open a PR with any changed banners
        uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "Update banners"
          branch: update-banners-${{ github.run_id }}
          title: "Update banners"
          body-path: check_size_report.txt
          add-paths: |
            images/dex/banner
            images/dex/thumbs
          delete-branch: true
```

The only functional changes from the current file: the new "Fetch dex banner-layers config from pokenini-api" step; `BANNER_CONFIG_FILE` set explicitly as an env var on the generation step instead of relying on `generate.sh`'s (now-nonexistent) default; the stale-cleanup step reading `$RUNNER_TEMP/dex-banner-layers.json` instead of `src/banner_generate/banners.json`. Everything else (webp conversion, thumbnails, size check, PR creation) is untouched.

No empty-PR guard is needed: `peter-evans/create-pull-request@v7` already skips opening a PR when the working tree has no changes after the run steps, and `make img_convert`/`make banner_thumb` are already idempotent (they skip files that already exist, per the top-level `README.md`'s existing "Banner generator" section) — so a run where every slug is skipped (or the fetched config is `{}`) naturally produces zero file changes and no PR, with no new code required for that case.

- [ ] **Step 2: Sanity-check the new YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/update-banners.yml'))"`
Expected: no output, exit code 0 (confirms valid YAML syntax — this workflow file's embedded shell blocks can't be executed locally since they need real GitHub Actions context and the two new secrets, so structural validation is what's available here).

Run: `bash -n <(python3 -c "
import yaml
doc = yaml.safe_load(open('.github/workflows/update-banners.yml'))
for step in doc['jobs']['update-banners']['steps']:
    if 'run' in step:
        print(step['run'])
        print('echo ---STEP-BOUNDARY---')
")`
Expected: no syntax errors reported (confirms every step's embedded shell script — including the two edited/new ones — is syntactically valid bash, without actually running any of it).

- [ ] **Step 3: Update the Makefile comment**

In `Makefile`, find:

```makefile
banner_generate: ## Composite banner PNGs from base.png + layers/ per banners.json
	bash src/banner_generate/generate.sh
```

Replace with:

```makefile
banner_generate: ## Composite banner PNGs from base.png + layers/ per $BANNER_CONFIG_FILE (see generate.sh; CI fetches this from pokenini-api, see .github/workflows/update-banners.yml)
	bash src/banner_generate/generate.sh
```

- [ ] **Step 4: Update the top-level `README.md`**

Find the "Banner generator" section (the paragraph starting "Composites banner PNGs from a base image..." through the end of the "Placeholder status" paragraph and the `update-banners` workflow description that follows it). Replace the whole section's body with:

```
Composites banner PNGs from a base image plus named overlay layers. The
slug → layers mapping is no longer a committed file — it's fetched at
generation time from `pokenini-api`'s `GET /istration/dex-banner-layers`
endpoint (Basic auth, `icon` user), which reflects the "Banner Layers"
column of the Dex tab in the Google Sheet `pokenini-api` syncs from. This
replaces the old manual pixlr/GIMP export workflow described in
`src/banner/README.md` (still current for exporting individual named
layers, see `src/banner/export_layers.sh`) as well as the earlier
committed-`banners.json` approach.

```
bash src/banner_generate/generate.sh [destDir]
```

`destDir` defaults to `images/dex/banner`. Also runnable via `make banner_generate`, but note `BANNER_CONFIG_FILE` must point at a real config file you provide yourself — there is no committed default anymore (see below).

Overridable env vars:

- `BANNER_BASE_IMAGE` (default `src/banner_generate/base.png`) — the base canvas every banner starts from.
- `BANNER_LAYERS_DIR` (default `src/banner_generate/layers`) — directory containing the named `<layer>.png` overlay files.
- `BANNER_CONFIG_FILE` (default `src/banner_generate/banners.json`, which no longer exists in this repo — always set this explicitly) — the slug -> layers config.
- `CONVERT_CONCURRENCY` (default `nproc`) — parallel `convert` workers.

The script hard-fails (non-zero exit, no files written) if the config file is
missing, isn't valid JSON, has a non-array value for any slug, or has any slug
mapped to an empty layer list `[]` — an empty list would otherwise silently
composite to "just the base image", producing a blank/placeholder-looking
banner instead of failing loudly. A slug whose output PNG already exists in
`destDir` is skipped (not regenerated) rather than erroring.

The `update-banners` GitHub workflow fetches the config from `pokenini-api`,
runs `generate.sh`, then deletes each regenerated banner's stale `.webp` and
thumbnail before `make img_convert` / `make banner_thumb` run (those two
scripts skip files that already exist, so without this cleanup a
regenerated PNG's derived outputs would never refresh).
```

- [ ] **Step 5: Run the existing test suite to confirm nothing broke**

Run: `bash src/banner_generate/test_generate.sh`
Expected: `All assertions passed` (this task doesn't touch `generate.sh`'s logic, only deletes an unrelated committed file and edits CI/docs, so this is a regression check, not new coverage).

- [ ] **Step 6: Commit**

```bash
git add -A src/banner_generate/banners.json .github/workflows/update-banners.yml Makefile README.md
git commit -m "feat: fetch banner-layers config from pokenini-api instead of a committed file"
```

---

### Task 3: Quality gate

**Files:** none new — verification only.

- [ ] **Step 1: Run the full local test suite**

Run: `bash src/banner_generate/test_generate.sh`
Expected: `All assertions passed`.

- [ ] **Step 2: Confirm the deleted file is really gone and nothing else references it**

Run: `grep -rn "banners\.json" --include="*.sh" --include="*.yml" --include="Makefile" --include="README.md" .`
Expected: no matches (everything that referenced the static file was updated in Task 2). If this finds a stray reference, fix it and re-commit before moving on.

- [ ] **Step 3: Commit any fixes found in Step 2**

```bash
git add -A
git commit -m "fix: remove any remaining banners.json references" --allow-empty
```

(Skip if Step 2 found nothing to fix.)

## Self-Review Notes

- **Spec coverage:** `generate.sh` skip-existing behavior ✓ (Task 1), `banners.json` retirement + API fetch in CI ✓ (Task 2), no automated test for the workflow YAML itself since none is possible in this repo without a live `pokenini-api` — mitigated with YAML/shell syntax validation (Task 2 Step 2) plus the design spec's explicit call-out that real verification is a manual post-merge trigger, matching how the rest of `update-banners.yml` has always been verified.
- **Placeholder scan:** none found — every step has real file paths, real diffs, real commands.
- **Type/interface consistency:** the endpoint path (`/istration/dex-banner-layers`), the auth user (`icon`), and the response shape (`{slug: [layers]}`, layers-less rows omitted) are used identically across Task 2's workflow YAML, its README update, and the Global Constraints section — all copied verbatim from the committed design spec, not re-derived.
