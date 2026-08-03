# Factor out the shared cwebp-conversion logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the duplicated `convert_one` (parallel `cwebp` conversion via `xargs -P`) logic shared by `download-from-pokemon-db/convert.sh` and `convert_png_webp/convert_png_webp.sh` into one new script, and reduce both callers to thin delegating wrappers.

**Architecture:** New `src/convert_webp/convert_webp.sh <directory> [label]` is the single implementation, invoked by direct sibling path (same convention as `copy_images.sh`/`validate_image.sh` — not a sourced library). Both existing scripts drop their own `convert_one`/`DONE_FILE`/`trap` and call the shared script instead.

**Tech Stack:** Bash, `cwebp`, GNU `xargs -P`/`find`.

## Global Constraints

- `cwebp` flags stay unchanged: `-quiet -q 100 -z 9 -m 6`.
- `CONVERT_CONCURRENCY` env var convention stays unchanged: `: "${CONVERT_CONCURRENCY:=$(nproc)}"`, so an already-exported caller value wins.
- `src/convert_webp/convert_webp.sh` must be executable (`chmod +x`) and called by direct relative path (`"$SCRIPT_DIR/../convert_webp/convert_webp.sh" ...`), matching the existing `copy_images.sh`/`validate_image.sh` convention — never `source`d.
- `download-from-pokemon-db/convert.sh`'s visible output must stay byte-identical to today (`"Start <file>"` / `"Done <N> of <total> <file>, in <T>s"`) — achieved via the `label` parameter.
- `convert_png_webp.sh`'s output gains a total count (`"Done <N> <dir>, in..."` → `"Done <N> of <total> <dir>, in..."`) — the one deliberate, approved output change in this plan.
- `download-from-pokemon-db/cp.sh` and `koenig-sprites/cp.sh` are out of scope — do not touch them.

---

## Task 1: Create the shared `convert_webp.sh`

**Files:**
- Create: `src/convert_webp/convert_webp.sh`
- Create: `src/convert_webp/test_convert_webp.sh`

**Interfaces:**
- Produces: `src/convert_webp/convert_webp.sh <directory> [label]` — converts every `*.png` directly inside `<directory>` (non-recursive) to a sibling `.webp` in parallel, skipping files whose `.webp` already exists. `label` defaults to `<directory>` when omitted. Reads `CONVERT_CONCURRENCY` (default `$(nproc)`). Prints `"Start <label>"` then `"Done <N> of <total> <label>, in <T>s"` to stdout. This is what Task 2 and Task 3 will call.

### Step 1: Write the script

```bash
mkdir -p /home/renaud/projects/pokenini-icon/src/convert_webp
cat > /home/renaud/projects/pokenini-icon/src/convert_webp/convert_webp.sh <<'SCRIPTEOF'
#!/bin/bash
shopt -s nullglob

directory=$1
label=${2:-$1}

: "${CONVERT_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s\n" "$label"

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

convert_one() {
    local image="$1"
    local filename=${image%.*}
    local destinationFile="$filename.webp"

    if [ ! -f "$destinationFile" ]; then
        cwebp -quiet -q 100 -z 9 -m 6 "$image" -o "$destinationFile"
        printf "DONE\n" >> "$DONE_FILE"
    fi
}
export -f convert_one
export DONE_FILE

pngs=("$directory"/*.png)
iTotal=${#pngs[@]}

if [ "$iTotal" -gt 0 ]; then
    printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'convert_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$label" $runtime

exit
SCRIPTEOF
chmod +x /home/renaud/projects/pokenini-icon/src/convert_webp/convert_webp.sh
```

### Step 2: Write the test

```bash
cat > /home/renaud/projects/pokenini-icon/src/convert_webp/test_convert_webp.sh <<'TESTEOF'
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$REPO_SCRIPT_DIR/convert_webp.sh"

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

# Scenario 1: skip-if-exists + default label (= directory path) + correct counts.
dir1="$workdir/dir1"
mkdir -p "$dir1"
convert -size 4x4 xc:red PNG32:"$dir1/one.png"
convert -size 4x4 xc:blue PNG32:"$dir1/two.png"
printf 'sentinel-content' > "$dir1/two.webp"

output=$(CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dir1" 2>&1)

assert_file_exists "one.webp converted" "$dir1/one.webp"
sentinel_after=$(cat "$dir1/two.webp")
assert_equals "pre-existing two.webp is left untouched" "sentinel-content" "$sentinel_after"
assert_matches "default label is the directory path (Start line)" "Start $dir1" "$output"
assert_matches "summary reports 1 of 2 using directory as label" "Done 1 of 2 $dir1, in [0-9]+s" "$output"

# Scenario 2: explicit label override.
dir2="$workdir/dir2"
mkdir -p "$dir2"
convert -size 4x4 xc:green PNG32:"$dir2/three.png"

output2=$(CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dir2" "custom-label" 2>&1)

assert_matches "explicit label used in Start line" "Start custom-label" "$output2"
assert_matches "explicit label used instead of directory path in summary" "Done 1 of 1 custom-label, in [0-9]+s" "$output2"

# Scenario 3: empty directory (nullglob) -> 0 of 0, no error.
dir3="$workdir/dir3"
mkdir -p "$dir3"

output3=$(CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dir3" 2>&1)

assert_matches "empty directory reports 0 of 0" "Done 0 of 0 $dir3, in [0-9]+s" "$output3"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
chmod +x /home/renaud/projects/pokenini-icon/src/convert_webp/test_convert_webp.sh
```

### Step 3: Run the test

```bash
bash /home/renaud/projects/pokenini-icon/src/convert_webp/test_convert_webp.sh
```

Expected: `All assertions passed`, exit code 0.

### Step 4: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/convert_webp/convert_webp.sh src/convert_webp/test_convert_webp.sh
git commit -m "$(cat <<'EOF'
Add shared convert_webp.sh (parallel cwebp conversion)

Extracts the convert_one/xargs -P logic that download-from-pokemon-db's
convert.sh and convert_png_webp.sh each currently duplicate. Not yet wired
up to either caller — that's the next two tasks.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 2: Wire `download-from-pokemon-db/convert.sh` to delegate

**Files:**
- Modify: `src/download-from-pokemon-db/convert.sh`
- Modify: `src/download-from-pokemon-db/test_convert.sh`

**Interfaces:**
- Consumes: `src/convert_webp/convert_webp.sh <directory> [label]` from Task 1 (already committed, do not modify it in this task).

### Step 1: Replace `convert.sh` with the thin wrapper

```bash
cat > /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/convert.sh <<'SCRIPTEOF'
#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

"$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$SCRIPT_DIR/images/temp/$file" "$file"
SCRIPTEOF
```

### Step 2: Fix the test's isolation setup

`test_convert.sh` currently copies only `convert.sh` into an isolated `mktemp -d` workdir, then runs it from there — this worked because the old `convert.sh` was fully self-contained. The new `convert.sh` calls a sibling script via a relative path (`$SCRIPT_DIR/../convert_webp/convert_webp.sh`), so the test workdir must now mirror that sibling relationship (a `download-from-pokemon-db/` dir next to a `convert_webp/` dir), not just hold `convert.sh` alone — otherwise the delegation fails to find its target. The assertions themselves (what text gets printed) do NOT change — only the setup paths do, since everything now lives one directory deeper (`$workdir/download-from-pokemon-db/...` instead of `$workdir/...`).

Replace the full contents of `/home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh` with:

```bash
cat > /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh <<'TESTEOF'
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_NAME="convert.sh"

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

# convert.sh now delegates to a sibling script via a relative path
# ($SCRIPT_DIR/../convert_webp/convert_webp.sh), so the isolated test
# workdir must mirror that sibling directory relationship, not just hold
# convert.sh alone, or the delegation call fails to find its target.
mkdir -p "$workdir/download-from-pokemon-db" "$workdir/convert_webp"
cp "$REPO_SCRIPT_DIR/$SCRIPT_NAME" "$workdir/download-from-pokemon-db/$SCRIPT_NAME"
cp "$REPO_SCRIPT_DIR/../convert_webp/convert_webp.sh" "$workdir/convert_webp/convert_webp.sh"

mkdir -p "$workdir/download-from-pokemon-db/images/temp/regular"
convert -size 4x4 xc:red PNG32:"$workdir/download-from-pokemon-db/images/temp/regular/one.png"
convert -size 4x4 xc:blue PNG32:"$workdir/download-from-pokemon-db/images/temp/regular/two.png"

# A pre-existing .webp for "two" must NOT be touched (skip-if-exists).
printf 'sentinel-content' > "$workdir/download-from-pokemon-db/images/temp/regular/two.webp"
sentinel_before=$(cat "$workdir/download-from-pokemon-db/images/temp/regular/two.webp")

output=$(cd "$workdir/download-from-pokemon-db" && CONVERT_CONCURRENCY=2 bash "./$SCRIPT_NAME" regular 2>&1)

assert_file_exists "one.webp was converted" "$workdir/download-from-pokemon-db/images/temp/regular/one.webp"

sentinel_after=$(cat "$workdir/download-from-pokemon-db/images/temp/regular/two.webp")
assert_equals "pre-existing two.webp is left untouched" "$sentinel_before" "$sentinel_after"

assert_matches "summary reports 1 done of 2" "Done 1 of 2 regular, in [0-9]+s" "$output"

# Empty directory: must not error and must report 0 of 0 (nullglob case).
mkdir -p "$workdir/download-from-pokemon-db/images/temp/shiny"
output_empty=$(cd "$workdir/download-from-pokemon-db" && CONVERT_CONCURRENCY=2 bash "./$SCRIPT_NAME" shiny 2>&1)
assert_matches "empty directory reports 0 of 0" "Done 0 of 0 shiny, in [0-9]+s" "$output_empty"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
```

### Step 3: Run the test

```bash
bash /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh
```

Expected: `All assertions passed`, exit code 0 — same assertions, same expected text, as before this task.

### Step 4: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/download-from-pokemon-db/convert.sh src/download-from-pokemon-db/test_convert.sh
git commit -m "$(cat <<'EOF'
Reduce download-from-pokemon-db/convert.sh to a convert_webp.sh wrapper

Output text is unchanged (label passed through explicitly as "$file").
test_convert.sh's setup now mirrors the real sibling-directory layout so
the delegated call to ../convert_webp/convert_webp.sh resolves inside the
isolated test workdir.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 3: Wire `convert_png_webp.sh` to delegate

**Files:**
- Modify: `src/convert_png_webp/convert_png_webp.sh`
- Modify: `src/convert_png_webp/test_convert_png_webp.sh`

**Interfaces:**
- Consumes: `src/convert_webp/convert_webp.sh <directory> [label]` from Task 1 (already committed, do not modify it in this task).

### Step 1: Replace `convert_png_webp.sh`'s loop body with a delegating call

```bash
cat > /home/renaud/projects/pokenini-icon/src/convert_png_webp/convert_png_webp.sh <<'SCRIPTEOF'
#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

directories=("images/banner" "images/big/regular" "images/big/shiny" "images/small/regular" "images/small/shiny")

for dir in "${directories[@]}"
do
    "$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$dir"
done

exit
SCRIPTEOF
```

Note: `directories` stays cwd-relative, exactly as before (the Makefile invokes this script from the repo root) — only the per-directory conversion logic moves out, into the shared script. `convert_webp.sh` receives each relative directory string and resolves it exactly as given, so this is a direct behavioral no-op for path resolution.

### Step 2: Update the two output-format assertions in the test

`convert_png_webp.sh`'s output now includes the total count (`convert_webp.sh`'s format), where it previously didn't. Everything else in the test — setup, the files it creates, which assertions exist — is unchanged, since (unlike Task 2) this script isn't copied elsewhere by the test; it's invoked at its real location, so its relative reference to `../convert_webp/convert_webp.sh` resolves correctly without any test setup changes.

Replace the full contents of `/home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh` with:

```bash
cat > /home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh <<'TESTEOF'
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$REPO_SCRIPT_DIR/convert_png_webp.sh"

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

assert_matches() {
    local desc="$1" pattern="$2" haystack="$3"
    if [[ "$haystack" =~ $pattern ]]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: output didn't match /%s/\n" "$desc" "$pattern"
        failures=$((failures + 1))
    fi
}

mkdir -p "$workdir/images/banner" "$workdir/images/big/regular" \
    "$workdir/images/big/shiny" "$workdir/images/small/regular" \
    "$workdir/images/small/shiny"

convert -size 4x4 xc:green PNG32:"$workdir/images/banner/a.png"
convert -size 4x4 xc:yellow PNG32:"$workdir/images/big/regular/b.png"

output=$(cd "$workdir" && CONVERT_CONCURRENCY=2 bash "$SCRIPT" 2>&1)

assert_file_exists "banner png converted" "$workdir/images/banner/a.webp"
assert_file_exists "big/regular png converted" "$workdir/images/big/regular/b.webp"

assert_matches "banner dir reports 1 of 1 done" "Done 1 of 1 images/banner, in [0-9]+s" "$output"
assert_matches "empty small/regular dir reports 0 of 0 done" "Done 0 of 0 images/small/regular, in [0-9]+s" "$output"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
```

### Step 3: Run the test

```bash
bash /home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh
```

Expected: `All assertions passed`, exit code 0.

### Step 4: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/convert_png_webp/convert_png_webp.sh src/convert_png_webp/test_convert_png_webp.sh
git commit -m "$(cat <<'EOF'
Reduce convert_png_webp.sh's loop body to a convert_webp.sh wrapper

Output now includes the "of N" total count (convert_webp.sh's format),
where it previously only printed the done count. Nothing outside the test
file parses this output text.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Final check

```bash
cd /home/renaud/projects/pokenini-icon
for t in \
    src/convert_webp/test_convert_webp.sh \
    src/download-from-pokemon-db/test_convert.sh \
    src/convert_png_webp/test_convert_png_webp.sh \
    src/download-from-pokemon-db/test_download-from-pokemondb.sh \
    src/copy_images/test_copy_images.sh \
    src/placeholders/test_make_them_all.sh \
    src/validate_image/test_validate_image.sh
do
    echo "=== $t ==="
    bash "$t" || echo "*** FAILED: $t ***"
done
```

Expected: every script prints `All assertions passed` and none print `FAILED`. The last four are pre-existing/unrelated suites, included as a full regression check since `convert.sh` and `convert_png_webp.sh` are both used by the CI workflow alongside them.
