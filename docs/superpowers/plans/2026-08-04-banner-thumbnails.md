# Banner Thumbnails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a script that generates 343px-wide (ratio-preserved) PNG thumbnails of `images/banner/*.png` into `images/banner/thumb/`, skipping files that already exist.

**Architecture:** A single new script `src/banner_thumb/banner_thumb.sh`, directly modeled on the existing `src/convert_webp/convert_webp.sh` (skip-if-exists, `xargs -P` parallelism, `Start`/`Done N of total` output), but calling ImageMagick's `convert <src> -resize <width>x <dst>` instead of `cwebp`. A new Makefile target `banner_thumb` wires it up. Confirmed by direct experiment: `convert -resize 343x` on a 578×325 source produces 343×193 (ImageMagick computes and rounds the height itself — nothing to hardcode).

**Tech Stack:** Bash, ImageMagick `convert`/`identify` (already a project dependency per `check_size.sh`/`validate_image.sh`), `xargs`, GNU `date`.

## Global Constraints

- Source banners live in `images/banner/*.png`, each 578×325 (per spec `docs/superpowers/specs/2026-08-04-banner-thumbnails-design.md`).
- PNG-only thumbnails — no `.webp` generation in this script (spec: out of scope, user-confirmed).
- Default thumbnail width: 343px. Script must accept a `width` override argument.
- Skip-if-exists: never overwrite an existing thumbnail file.
- Follow existing script conventions exactly: `shopt -s nullglob`, `: "${VAR:=default}"` for the concurrency env var, `mktemp`/`trap ... EXIT` for the done-counter file, `printf '%s\0' ... | xargs -0 -P "$CONCURRENCY" -I{} bash -c '...' _ {}` for parallelism, `Start <label>` / `Done <N> of <total> <label>, in <T>s` output format.
- Test style: real `convert`/`identify` binaries, no mocks, bash assertion helpers (`assert_file_exists`, `assert_equals`, `assert_matches`) copied verbatim from `src/convert_webp/test_convert_webp.sh`.

---

### Task 1: `banner_thumb.sh` script + tests + Makefile target

**Files:**
- Create: `src/banner_thumb/banner_thumb.sh`
- Create: `src/banner_thumb/test_banner_thumb.sh`
- Modify: `Makefile` (add `banner_thumb` target, in the `## —— Images` section after `img_convert`)

**Interfaces:**
- Produces: `src/banner_thumb/banner_thumb.sh <sourceDir> <destDir> [width=343]` — an executable script with no other consumers in this plan.

- [ ] **Step 1: Write the failing test file**

Create `src/banner_thumb/test_banner_thumb.sh`:

```bash
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$REPO_SCRIPT_DIR/banner_thumb.sh"

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

# Scenario 1: default width (343) resizes a 578x325 source to 343x193,
# skip-if-exists leaves a pre-existing thumbnail untouched, and destDir
# is created automatically.
dir1="$workdir/dir1"
mkdir -p "$dir1"
convert -size 578x325 xc:red PNG32:"$dir1/one.png"
convert -size 578x325 xc:blue PNG32:"$dir1/two.png"
dest1="$workdir/dir1/thumb"
mkdir -p "$dest1"
printf 'sentinel-content' > "$dest1/two.png"

output=$(CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dir1" "$dest1" 2>&1)

assert_file_exists "one.png thumbnail created" "$dest1/one.png"
size_one=$(identify -format "%wx%h" "$dest1/one.png")
assert_equals "one.png thumbnail is 343x193 (578x325 scaled to 343 wide)" "343x193" "$size_one"
sentinel_after=$(cat "$dest1/two.png")
assert_equals "pre-existing two.png thumbnail is left untouched" "sentinel-content" "$sentinel_after"
assert_matches "summary reports 1 of 2" "Done 1 of 2 $dir1, in [0-9]+s" "$output"

# Scenario 2: destDir doesn't exist yet -> script creates it.
dir2="$workdir/dir2"
mkdir -p "$dir2"
convert -size 578x325 xc:green PNG32:"$dir2/three.png"
dest2="$workdir/dir2/thumb"

bash "$SCRIPT" "$dir2" "$dest2" > /dev/null 2>&1

assert_file_exists "destDir auto-created" "$dest2"
assert_file_exists "three.png thumbnail created in auto-created destDir" "$dest2/three.png"

# Scenario 3: custom width argument (100) resizes 578x325 to 100x56.
dir3="$workdir/dir3"
mkdir -p "$dir3"
convert -size 578x325 xc:yellow PNG32:"$dir3/four.png"
dest3="$workdir/dir3/thumb"

bash "$SCRIPT" "$dir3" "$dest3" 100 > /dev/null 2>&1

size_four=$(identify -format "%wx%h" "$dest3/four.png")
assert_equals "custom width 100 resizes 578x325 to 100x56" "100x56" "$size_four"

# Scenario 4: empty directory (nullglob) -> 0 of 0, no error.
dir4="$workdir/dir4"
mkdir -p "$dir4"
dest4="$workdir/dir4/thumb"

output4=$(bash "$SCRIPT" "$dir4" "$dest4" 2>&1)

assert_matches "empty directory reports 0 of 0" "Done 0 of 0 $dir4, in [0-9]+s" "$output4"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x src/banner_thumb/test_banner_thumb.sh && bash src/banner_thumb/test_banner_thumb.sh`
Expected: FAIL — `bash: src/banner_thumb/banner_thumb.sh: No such file or directory` (script doesn't exist yet).

- [ ] **Step 3: Write the script implementation**

Create `src/banner_thumb/banner_thumb.sh`:

```bash
#!/bin/bash
shopt -s nullglob

sourceDir=$1
destDir=$2
width=${3:-343}

: "${CONVERT_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s\n" "$sourceDir"

mkdir -p "$destDir"

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

thumb_one() {
    local image="$1"
    local filename=${image##*/}
    local destinationFile="$destDir/$filename"

    if [ ! -f "$destinationFile" ]; then
        convert "$image" -resize "${width}x" "$destinationFile"
        printf "DONE\n" >> "$DONE_FILE"
    fi
}
export -f thumb_one
export destDir width DONE_FILE

pngs=("$sourceDir"/*.png)
iTotal=${#pngs[@]}

if [ "$iTotal" -gt 0 ]; then
    printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'thumb_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$sourceDir" $runtime

exit
```

Make it executable: `chmod +x src/banner_thumb/banner_thumb.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash src/banner_thumb/test_banner_thumb.sh`
Expected: `All assertions passed`, exit code 0. If Scenario 1's `343x193` assertion fails on this machine's ImageMagick version, run the two-line experiment from the design doc directly (`convert -size 578x325 xc:red PNG32:/tmp/t.png && convert /tmp/t.png -resize 343x /tmp/o.png && identify -format "%wx%h" /tmp/o.png`) and update the expected value in the test to match — the goal is that the test documents actual `convert` behavior, not a hand-derived number.

- [ ] **Step 5: Add the Makefile target**

In `Makefile`, in the `## —— Images` section, after the existing `img_convert` target:

```makefile
.PHONY        : banner_thumb
banner_thumb: ## Generate 343px-wide banner thumbnails
	bash src/banner_thumb/banner_thumb.sh images/banner images/banner/thumb
```

- [ ] **Step 6: Manually verify the Makefile target against the real banner directory**

Run: `make banner_thumb`
Expected: `Start images/banner` then `Done <N> of <N> images/banner, in <T>s` where `<N>` is the current count of `images/banner/*.png`. Then run `identify -format "%wx%h\n" images/banner/thumb/all.png` (or any generated file) and confirm the width is `343`.

Clean up the generated directory before committing (it's a build artifact, not source — confirm `images/banner/thumb/` is not meant to be committed; if the user wants generated thumbnails tracked in git, that's a follow-up decision outside this plan's scope):

Run: `git status --short images/banner/thumb/` — if it shows up as untracked, leave it untracked (don't `git add` it) unless told otherwise.

- [ ] **Step 7: Commit**

```bash
git add src/banner_thumb/banner_thumb.sh src/banner_thumb/test_banner_thumb.sh Makefile
git commit -m "$(cat <<'EOF'
Add banner_thumb.sh to generate 343px-wide banner thumbnails

EOF
)"
```
