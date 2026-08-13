# Banner Generator (pokenini-icon) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace manual per-banner GIMP export with a scripted ImageMagick composite (base + named layers, driven by a JSON config), wired into the existing `img_convert`/`banner_thumb`/`check_size` Makefile pipeline, plus a `workflow_dispatch` GitHub Actions workflow that runs it and opens a review PR.

**Architecture:** A new `src/banner_generate/` module: `base.png` + `layers/*.png` (578×325 canvas, transparent, exported once from GIMP) + `banners.json` (slug → ordered layer list) + `generate.sh` (bash, ImageMagick `convert -composite`, same `xargs -P`/`mktemp` concurrency pattern as `src/banner_thumb/banner_thumb.sh`). A new Makefile target `banner_generate` runs it before the existing `img_convert`/`banner_thumb`/`check_size` targets. A new `update-banners.yml` workflow (`workflow_dispatch`, mirrors `update-images.yml`) chains all four and opens a PR.

**Tech Stack:** bash, ImageMagick (`convert`), `jq`, GitHub Actions, `peter-evans/create-pull-request@v7`.

## Global Constraints

- Every layer PNG (including `base.png`) is exported at the full 578×325 canvas with transparency — no per-layer positioning/cropping.
- A banner referencing a missing layer file must fail the script (non-zero exit, clear stderr message) — never silently skip or produce a wrong image.
- No change to `img_convert`, `banner_thumb`, or `check_size` Makefile targets — all three are already generic over `images/`.
- No change to `publish-images-to-resources.yml` — it already triggers on `push` to `main` under `images/**`.
- Migrating the ~85 existing banners' real layer composition into `banners.json` is out of scope for this plan (see spec's non-goals) — this plan seeds `banners.json` with the 85 known slugs mapped to empty layer lists (valid, generates a blank base-only PNG per slug), to be filled in by hand afterward.

---

### Task 1: `generate.sh` + config + Makefile target

**Files:**
- Create: `src/banner_generate/base.png` (placeholder 578×325 transparent PNG for now — real artwork is exported from GIMP separately, out of scope here)
- Create: `src/banner_generate/layers/.gitkeep`
- Create: `src/banner_generate/banners.json`
- Create: `src/banner_generate/generate.sh`
- Create: `src/banner_generate/test_generate.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces: `bash src/banner_generate/generate.sh [destDir]` (default `destDir=images/dex/banner`), reading `banners.json`/`base.png`/`layers/` from the script's own directory by default, overridable via env vars `BANNER_BASE_IMAGE`, `BANNER_LAYERS_DIR`, `BANNER_CONFIG_FILE` (same override pattern `test_generate.sh` uses to point at fixtures). `make banner_generate` Makefile target invoking it with no arguments.

- [ ] **Step 1: Write `generate.sh`**

```bash
#!/bin/bash
set -euo pipefail
shopt -s nullglob

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_BASE_IMAGE:=$scriptDir/base.png}"
: "${BANNER_LAYERS_DIR:=$scriptDir/layers}"
: "${BANNER_CONFIG_FILE:=$scriptDir/banners.json}"
: "${CONVERT_CONCURRENCY:=$(nproc)}"

destDir=${1:-images/dex/banner}

mkdir -p "$destDir"

if [ ! -f "$BANNER_BASE_IMAGE" ]; then
    printf "ERROR: base image not found: %s\n" "$BANNER_BASE_IMAGE" >&2
    exit 1
fi

mapfile -t slugs < <(jq -r 'keys[]' "$BANNER_CONFIG_FILE")

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile

    while IFS= read -r layer; do
        layerFile="$BANNER_LAYERS_DIR/$layer.png"
        if [ ! -f "$layerFile" ]; then
            printf "ERROR: layer '%s' referenced by banner '%s' not found: %s\n" "$layer" "$slug" "$layerFile" >&2
            exit 1
        fi
        args+=("$layerFile" -composite)
    done < <(jq -r --arg slug "$slug" '.[$slug][]' "$BANNER_CONFIG_FILE")

    convert "${args[@]}" "$destinationFile"
    printf "DONE\n" >> "$DONE_FILE"
}
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE DONE_FILE

if [ "${#slugs[@]}" -gt 0 ]; then
    printf '%s\0' "${slugs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'generate_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")
printf "Generated %d of %d banners\n" "$iDone" "${#slugs[@]}"
```

Make it executable: `chmod +x src/banner_generate/generate.sh`.

- [ ] **Step 2: Write `test_generate.sh`**

```bash
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$REPO_SCRIPT_DIR/generate.sh"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

failures=0

assert_file_exists() {
    local desc="$1" file="$2"
    if [ -f "$file" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to exist\n" "$desc" "$file"
        failures=$((failures + 1))
    fi
}

assert_equals() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected '%s', got '%s'\n" "$desc" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

assert_matches() {
    local desc="$1" pattern="$2" haystack="$3"
    if [[ "$haystack" =~ $pattern ]]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: output didn't match /%s/\n" "$desc" "$pattern"
        failures=$((failures + 1))
    fi
}

# Scenario 1: single-layer and multi-layer banners composite correctly,
# and output size matches the 578x325 canvas.
dir1="$workdir/dir1"
mkdir -p "$dir1/layers"
convert -size 578x325 xc:red PNG32:"$dir1/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir1/layers/logoA.png"
convert -size 578x325 xc:none -fill green -draw "rectangle 200,200 300,300" PNG32:"$dir1/layers/logoB.png"
cat > "$dir1/banners.json" <<'JSON'
{
  "single": ["logoA"],
  "multi": ["logoA", "logoB"]
}
JSON
dest1="$workdir/dir1/out"

output1=$(BANNER_BASE_IMAGE="$dir1/base.png" BANNER_LAYERS_DIR="$dir1/layers" BANNER_CONFIG_FILE="$dir1/banners.json" CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dest1" 2>&1)

assert_file_exists "single.png created" "$dest1/single.png"
assert_file_exists "multi.png created" "$dest1/multi.png"
size_single=$(identify -format "%wx%h" "$dest1/single.png")
assert_equals "single.png keeps the 578x325 canvas" "578x325" "$size_single"
assert_matches "summary reports 2 of 2" "Generated 2 of 2 banners" "$output1"

# Scenario 2: a banner referencing a missing layer fails loudly.
dir2="$workdir/dir2"
mkdir -p "$dir2/layers"
convert -size 578x325 xc:red PNG32:"$dir2/base.png"
cat > "$dir2/banners.json" <<'JSON'
{
  "broken": ["does-not-exist"]
}
JSON
dest2="$workdir/dir2/out"

set +e
output2=$(BANNER_BASE_IMAGE="$dir2/base.png" BANNER_LAYERS_DIR="$dir2/layers" BANNER_CONFIG_FILE="$dir2/banners.json" bash "$SCRIPT" "$dest2" 2>&1)
exit_code2=$?
set -e

assert_equals "missing layer exits non-zero" "1" "$exit_code2"
assert_matches "missing layer error names the layer and the banner" "ERROR: layer 'does-not-exist' referenced by banner 'broken' not found" "$output2"

# Scenario 3: empty config -> succeeds, generates nothing.
dir3="$workdir/dir3"
mkdir -p "$dir3/layers"
convert -size 578x325 xc:red PNG32:"$dir3/base.png"
printf '{}' > "$dir3/banners.json"
dest3="$workdir/dir3/out"

output3=$(BANNER_BASE_IMAGE="$dir3/base.png" BANNER_LAYERS_DIR="$dir3/layers" BANNER_CONFIG_FILE="$dir3/banners.json" bash "$SCRIPT" "$dest3" 2>&1)

assert_matches "empty config reports 0 of 0" "Generated 0 of 0 banners" "$output3"

# Scenario 4: missing base image fails loudly before touching destDir.
dir4="$workdir/dir4"
mkdir -p "$dir4/layers"
printf '{}' > "$dir4/banners.json"
dest4="$workdir/dir4/out"

set +e
output4=$(BANNER_BASE_IMAGE="$dir4/base.png" BANNER_LAYERS_DIR="$dir4/layers" BANNER_CONFIG_FILE="$dir4/banners.json" bash "$SCRIPT" "$dest4" 2>&1)
exit_code4=$?
set -e

assert_equals "missing base image exits non-zero" "1" "$exit_code4"
assert_matches "missing base image error is clear" "ERROR: base image not found" "$output4"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
```

Make it executable: `chmod +x src/banner_generate/test_generate.sh`.

- [ ] **Step 3: Run the test — expect it to fail if ImageMagick/jq aren't installed on this host, otherwise pass**

Run: `bash src/banner_generate/test_generate.sh`
Expected: `All assertions passed` (this script has no separate "fails first" step since it's a fresh implementation, not a red/green unit test — but if `convert`/`jq` are missing on the host, run it inside the `php` container or install `imagemagick`/`webp`/`jq` first, matching `update-images.yml`'s own `apt-get install` step).

- [ ] **Step 4: Seed `base.png` (placeholder), `layers/.gitkeep`, and `banners.json` with the 85 known slugs**

`base.png` is a placeholder until real artwork is exported from GIMP (out of scope — see Global Constraints). Create a valid 578×325 transparent placeholder:

```bash
convert -size 578x325 xc:none PNG32:src/banner_generate/base.png
touch src/banner_generate/layers/.gitkeep
```

Seed `banners.json` with the 85 slugs already present in `images/dex/banner/`, each mapped to an empty layer list (valid config — `generate.sh` will produce a blank/base-only PNG per slug until real layers are filled in by hand, a follow-up content task, not a coding task):

```bash
ls images/dex/banner | sed -E 's/\.(png|webp)$//' | sort -u \
  | jq -R -s 'split("\n") | map(select(length > 0)) | map({(.): []}) | add' \
  > src/banner_generate/banners.json
```

Verify it parses and has 85 keys: `jq 'keys | length' src/banner_generate/banners.json` → expect `85`.

- [ ] **Step 5: Add the Makefile target**

In `Makefile`, add near the other `img_*`/`banner_*` targets (after the existing `banner_thumb` target, `Makefile:50-52`):

```makefile
.PHONY        : banner_generate
banner_generate: ## Composite banner PNGs from base.png + layers/ per banners.json
	bash src/banner_generate/generate.sh
```

- [ ] **Step 6: Run `make banner_generate` and confirm it produces the (currently blank) 85 banner PNGs without error**

Run: `make banner_generate`
Expected: `Generated 85 of 85 banners`, and `images/dex/banner/*.png` all present (still blank/transparent until real layers are added — that's expected at this stage).

- [ ] **Step 7: Commit**

```bash
git add src/banner_generate Makefile
git commit -m "feat: add scripted banner generator (base + layers -> composite)"
```

---

### Task 2: `update-banners.yml` GitHub Actions workflow

**Files:**
- Create: `.github/workflows/update-banners.yml`

**Interfaces:**
- Consumes: `make banner_generate` (Task 1), `make img_convert`, `make banner_thumb`, `make check_size` (all pre-existing, unmodified).
- Produces: a `workflow_dispatch`-triggered GitHub Actions job named `update-banners`, discoverable by `pokenini-back`'s future `GithubActionsApiService`/`GithubQueryApiService` calls (see the `pokenini-back` plan) via workflow file name `update-banners.yml` and `run-name` `"Update banners (<correlation_id>)"`.

- [ ] **Step 1: Write the workflow file**

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

      - name: Generate banner PNGs from base + layers
        run: make banner_generate

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

- [ ] **Step 2: Validate the workflow YAML parses correctly**

Run: `docker run --rm -v "$PWD/.github/workflows/update-banners.yml:/wf.yml" mikefarah/yq eval /wf.yml > /dev/null && echo OK`

(Or any YAML linter available; the goal is just to catch a syntax error before pushing — GitHub itself will reject a malformed workflow file at dispatch time otherwise.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/update-banners.yml
git commit -m "ci: add update-banners workflow_dispatch pipeline"
```

- [ ] **Step 4: Validate end-to-end on GitHub once pushed**

Run: `gh workflow run update-banners.yml -f correlation_id=manual-test-1`, then check the Actions tab for a successful run and the resulting PR (`add-paths` limits it to `images/dex/banner` and `images/dex/thumbs`, so with today's still-blank `base.png`/empty `banners.json` layer lists this PR is expected to be a no-diff / no-PR outcome the first time, and a real diff once real layers are added later). This matches how `update-images.yml` was originally validated — no CI-for-CI unit tests for the workflow file itself.

## Self-Review Notes

- **Spec coverage**: banner generation script (Task 1) ✓, `update-banners.yml` (Task 2) ✓, no changes to `img_convert`/`banner_thumb`/`check_size`/`publish-images-to-resources.yml` ✓ (none touched). Migration of real layer content is explicitly out of scope per the spec's non-goals and this plan's Global Constraints.
- **Placeholder scan**: `base.png` is a real, valid, generated file (transparent placeholder), not a TODO; `banners.json` is fully seeded with real slugs and valid (empty-array) values, not a stub with a "fill me in" comment.
- **Type/name consistency**: `generate.sh`'s env var names (`BANNER_BASE_IMAGE`, `BANNER_LAYERS_DIR`, `BANNER_CONFIG_FILE`, `CONVERT_CONCURRENCY`) are used identically in both the script and `test_generate.sh`; the Makefile target name `banner_generate` matches the workflow step and the spec.
