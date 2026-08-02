# Parallelize pokemondb download/convert/copy pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the sequential per-file loops in the pokemondb "big sprite" pipeline (download, webp-convert, copy-and-validate) and the shared `convert_png_webp.sh` into `xargs -P`-parallelized versions, and stop CI from re-downloading/re-converting everything on every run.

**Architecture:** Each script's per-item loop body becomes a `bash` function, exported with `export -f` and driven by `xargs -P "$CONCURRENCY" -0 -I{} bash -c '... "$@"' _ {}` over a NUL-delimited file list. Workers never mutate parent-shell counters (impossible across `xargs -P` child processes); instead each worker appends a short tagged line to a temp results file (safe under concurrent `>>` since every write is well under `PIPE_BUF`), and the parent derives final counts with `wc -l` / `grep -c` after `xargs` returns. A GitHub Actions cache step is added for the one directory (`images/temp/`) that both the download and convert steps read/write, keyed with the "always fall through to restore-keys" pattern so every run both restores the latest cache and saves a fresh one.

**Tech Stack:** Bash, GNU `xargs`/`find` (`-P`, `-0`, already present on the dev host and `ubuntu-latest`), `wget`, `cwebp`, ImageMagick (`identify`, `compare`), GitHub Actions (`actions/cache@v4`).

## Global Constraints

- No new external dependencies (no GNU `parallel`) — `xargs -P` only, per spec decision.
- Concurrency is configurable via env vars with defaults: `DOWNLOAD_CONCURRENCY=8`, `CONVERT_CONCURRENCY=$(nproc)`, `COPY_CONCURRENCY=$(nproc)` — set with `: "${VAR:=default}"` so an already-exported value from the caller/Makefile/CI wins.
- `cwebp` flags (`-q 100 -z 9 -m 6`) are unchanged — not in scope.
- `copy_images.sh`'s final summary line format `"Done %d (%d new) of %d %s, in %ds\n"` and its per-file `Reject %s: %s` / `Copy %s` lines must stay byte-identical — `test_copy_images.sh` asserts on this text verbatim.
- Concurrent appends to any shared report/results file are safe as-is (single short line per write, under `PIPE_BUF`) — no `flock` needed anywhere in this plan.

---

## Task 1: Parallelize `download-from-pokemondb.sh`

**Files:**
- Modify: `src/download-from-pokemon-db/download-from-pokemondb.sh`
- Create: `src/download-from-pokemon-db/test_download-from-pokemondb.sh`
- Revert: `src/download-from-pokemon-db/pokemons-list.txt` (currently has an uncommitted trailing blank line — see Step 1)

**Interfaces:**
- Produces: env var `DOWNLOAD_CONCURRENCY` (default `8`), consumed only by this script.
- Produces: `report_failed_regular.txt` / `report_failed_shiny.txt` in `$SCRIPT_DIR` — same format as before (one failed CSV line per row), consumed by nothing else in this repo (informational only).

### Step 1: Revert the stray trailing-blank-line diff in `pokemons-list.txt`, then confirm the bug

The current working tree has `src/download-from-pokemon-db/pokemons-list.txt` modified by exactly one trailing blank line. This is caused by `download-from-pokemondb.sh:51` (`echo '' >> "$list"`), which permanently mutates the *input* list file every time the script runs — a real bug, and the reason this file shows as locally modified. Revert it first so we start from a clean baseline, then look at the line causing it:

```bash
git status --porcelain src/download-from-pokemon-db/pokemons-list.txt
# confirm it shows exactly "M src/download-from-pokemon-db/pokemons-list.txt" and nothing else staged
git diff src/download-from-pokemon-db/pokemons-list.txt
# confirm the diff is only "+" one blank line at EOF
git checkout -- src/download-from-pokemon-db/pokemons-list.txt
git status --porcelain src/download-from-pokemon-db/pokemons-list.txt
# expect: no output (clean)
```

### Step 2: Write the test script (fails against the current script)

```bash
cat > /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_download-from-pokemondb.sh <<'TESTEOF'
#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_NAME="download-from-pokemondb.sh"

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

assert_file_not_exists() {
    local desc="$1" file="$2"
    if [ ! -f "$file" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to NOT exist\n" "$desc" "$file"
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

assert_equals() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected '%s', got '%s'\n" "$desc" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

# The script keys its output paths off its own location (SCRIPT_DIR), not
# the caller's cwd, so it's copied into an isolated workdir to run — this
# keeps the test from writing into the real repo's images/temp/.
cp "$REPO_SCRIPT_DIR/$SCRIPT_NAME" "$workdir/$SCRIPT_NAME"

# Fake wget: "good*" source names succeed with fake image bytes, "bad*"
# source names simulate a 404 (empty output), matching how the real script
# detects failure (-s check on the downloaded file).
mkdir -p "$workdir/bin"
cat > "$workdir/bin/wget" <<'EOF'
#!/bin/bash
out=""
url=""
while [ $# -gt 0 ]; do
    case "$1" in
        -O) out="$2"; shift 2 ;;
        --no-cache|-q) shift ;;
        *) url="$1"; shift ;;
    esac
done
if [[ "$url" == *"/bad"* ]]; then
    : > "$out"
else
    printf 'fake-image-bytes' > "$out"
fi
EOF
chmod +x "$workdir/bin/wget"

list="$workdir/list.txt"
cat > "$list" <<'EOF'
good1,home,good1
bad1,home,bad1
good2,home,good2
EOF
list_before=$(cat "$list")

output=$(cd "$workdir" && PATH="$workdir/bin:$PATH" DOWNLOAD_CONCURRENCY=3 \
    bash "./$SCRIPT_NAME" "$list" rs 2>&1)

list_after=$(cat "$list")

assert_equals "input list file is never mutated by the script" "$list_before" "$list_after"

assert_file_exists "good1 regular downloaded" "$workdir/images/temp/regular/good1.png"
assert_file_exists "good1 shiny downloaded" "$workdir/images/temp/shiny/good1.png"
assert_file_exists "good2 regular downloaded" "$workdir/images/temp/regular/good2.png"
assert_file_exists "good2 shiny downloaded" "$workdir/images/temp/shiny/good2.png"

assert_file_not_exists "bad1 regular not kept (empty download removed)" "$workdir/images/temp/regular/bad1.png"
assert_file_not_exists "bad1 shiny not kept (empty download removed)" "$workdir/images/temp/shiny/bad1.png"

failedRegular=$(cat "$workdir/report_failed_regular.txt")
failedShiny=$(cat "$workdir/report_failed_shiny.txt")

assert_matches "bad1 recorded in failed-regular report" "bad1,home,bad1" "$failedRegular"
assert_matches "bad1 recorded in failed-shiny report" "bad1,home,bad1" "$failedShiny"


# 3 list entries, both regular+shiny requested ("rs") -> totalCount is
# doubled (count * 2 variants) = 6, regardless of the 1 failure on each
# side — matches the original script's (buggy-but-unchanged) semantics of
# not subtracting failures from totalCount, just now actually computing a
# real number instead of always reading back 0.
assert_matches "final summary line printed" "Done 6, 1\+1, in [0-9]+s" "$output"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
chmod +x /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_download-from-pokemondb.sh
```

### Step 3: Run the test against the current (sequential) script — confirm the mutation assertion fails

```bash
bash /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_download-from-pokemondb.sh
```

Expected: two failures against the current script:
- `FAIL input list file is never mutated by the script: expected '...good2,home,good2', got '...good2,home,good2\n'` — the exact bug Step 1 already flagged (`echo '' >> "$list"`).
- `FAIL final summary line printed: output didn't match ...` — `report_done.txt` is always empty (dead code, nothing ever appends to it), so `totalCount` always reads back `0` (`Done 0, 1+1, in Ns`) instead of the real count.

Everything else should already pass, since the download/failure-detection behavior itself is otherwise correct in the sequential version.

### Step 4: Replace `download-from-pokemondb.sh` with the parallel version

```bash
cat > /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/download-from-pokemondb.sh <<'SCRIPTEOF'
#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

list=$1

cat=$2

case $cat in

    "r")
        downloadRegulars=true
        downloadShinies=false
        ;;

    "s")
        downloadRegulars=false
        downloadShinies=true
        ;;

    "rs")
        downloadRegulars=true
        downloadShinies=true
        ;;

    "sr")
        downloadRegulars=true
        downloadShinies=true
        ;;

    *)
        downloadRegulars=true
        downloadShinies=true
        ;;
esac

: "${DOWNLOAD_CONCURRENCY:=8}"

# Downloads
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/temp/regular"
mkdir -p "$SCRIPT_DIR/images/temp/shiny"

echo '' > "$SCRIPT_DIR/report_failed_regular.txt"
echo '' > "$SCRIPT_DIR/report_failed_shiny.txt"

startAll=`date +%s`
count=$(wc -l < "$list")

download_one() {
    local line="$1"
    local data

    IFS=',' read -a data <<< "$line"

    local sourceFileName=${data[0]}
    local sourceDirName=${data[1]}
    local targetFileName=${data[2]}

    if [ -z "$sourceFileName" ] || [ -z "$sourceDirName" ] || [ -z "$targetFileName" ]
    then
        return
    fi

    if [ "$downloadRegulars" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/normal/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            rm -f "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
            echo "$line" >> "$SCRIPT_DIR/report_failed_regular.txt"
        fi
    fi

    if [ "$downloadShinies" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/shiny/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            rm -f "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
            echo "$line" >> "$SCRIPT_DIR/report_failed_shiny.txt"
        fi
    fi
}
export -f download_one
export SCRIPT_DIR downloadRegulars downloadShinies

cat "$list" | xargs -d '\n' -P "$DOWNLOAD_CONCURRENCY" -I{} bash -c 'download_one "$@"' _ {}

runtime=$(((`date +%s`)-startAll))

sed -i '/^$/d' "$SCRIPT_DIR/report_failed_regular.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_shiny.txt"

failRegulars=$(wc -l < "$SCRIPT_DIR/report_failed_regular.txt")
failShinies=$(wc -l < "$SCRIPT_DIR/report_failed_shiny.txt")

totalCount=$count
if [ "$downloadRegulars" = true ] && [ "$downloadShinies" = true ]
then
    ((totalCount+=$totalCount))
fi

printf "Done %d, %d+%d, in %ds\n" "$totalCount" "$failRegulars" "$failShinies" "$runtime"

exit
SCRIPTEOF
```

Notes on what changed vs. the original, and why:
- Dropped `echo '' >> "$list"` (was needed so `while read` wouldn't drop a final line without a trailing newline — `cat "$list" | xargs -d '\n'` doesn't need that trick, and it was mutating the committed input file as a side effect, per Step 1).
- Dropped `report_done.txt` entirely: it was created but never appended to (dead code — grep confirmed no other write site), so `totalCount` always read back `0`. `totalCount` is now derived from `$count` (already computed via `wc -l < "$list"`), matching the original's intent (double it when both variants are downloaded).
- Dropped the modulo-based progress printer (`$i % 100` etc.) — it assumed a known sequential completion order, which no longer holds under `xargs -P`.

### Step 5: Run the test again — confirm it passes

```bash
bash /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_download-from-pokemondb.sh
```

Expected: `All assertions passed`, exit code 0.

### Step 6: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/test_download-from-pokemondb.sh
git commit -m "$(cat <<'EOF'
Parallelize download-from-pokemondb.sh with xargs -P

Sequential wget-per-sprite (up to 3354 calls) was the main source of the
slow "big sprite" download. Also drops the input-list mutation hack (was
appending a blank line to pokemons-list.txt on every run) and a dead
report_done.txt counter that always reported 0.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 2: Parallelize `convert.sh`

**Files:**
- Modify: `src/download-from-pokemon-db/convert.sh`
- Create: `src/download-from-pokemon-db/test_convert.sh`

**Interfaces:**
- Produces: env var `CONVERT_CONCURRENCY` (default `$(nproc)`), consumed by this script and Task 3's `convert_png_webp.sh` independently (no shared code between them, just the same convention).

### Step 1: Write the test script

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

# convert.sh keys its source dir off its own SCRIPT_DIR, so it's copied
# into the isolated workdir to run, same reasoning as
# test_download-from-pokemondb.sh.
cp "$REPO_SCRIPT_DIR/$SCRIPT_NAME" "$workdir/$SCRIPT_NAME"

mkdir -p "$workdir/images/temp/regular"
convert -size 4x4 xc:red PNG32:"$workdir/images/temp/regular/one.png"
convert -size 4x4 xc:blue PNG32:"$workdir/images/temp/regular/two.png"

# A pre-existing .webp for "two" must NOT be touched (skip-if-exists).
printf 'sentinel-content' > "$workdir/images/temp/regular/two.webp"
sentinel_before=$(cat "$workdir/images/temp/regular/two.webp")

output=$(cd "$workdir" && CONVERT_CONCURRENCY=2 bash "./$SCRIPT_NAME" regular 2>&1)

assert_file_exists "one.webp was converted" "$workdir/images/temp/regular/one.webp"

sentinel_after=$(cat "$workdir/images/temp/regular/two.webp")
assert_equals "pre-existing two.webp is left untouched" "$sentinel_before" "$sentinel_after"

assert_matches "summary reports 1 done of 2" "Done 1 of 2 regular, in [0-9]+s" "$output"

# Empty directory: must not error and must report 0 of 0 (nullglob case).
mkdir -p "$workdir/images/temp/shiny"
output_empty=$(cd "$workdir" && CONVERT_CONCURRENCY=2 bash "./$SCRIPT_NAME" shiny 2>&1)
assert_matches "empty directory reports 0 of 0" "Done 0 of 0 shiny, in [0-9]+s" "$output_empty"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
chmod +x /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh
```

### Step 2: Run the test against the current (sequential) script — confirm the empty-directory case fails

```bash
bash /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh
```

Expected: `FAIL empty directory reports 0 of 0: output didn't match ...` — the current script has no `nullglob`, so `for image in $images` iterates once over the literal, unexpanded glob string when the directory is empty, producing wrong/garbage output instead of `Done 0 of 0`.

### Step 3: Replace `convert.sh` with the parallel version

```bash
cat > /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/convert.sh <<'SCRIPTEOF'
#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

: "${CONVERT_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s\n" "$file"

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

pngs=("$SCRIPT_DIR/images/temp/$file"/*.png)
iTotal=${#pngs[@]}

if [ "$iTotal" -gt 0 ]; then
    printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'convert_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$file" $runtime

exit
SCRIPTEOF
```

Note: added `shopt -s nullglob` (was missing) so an empty source directory correctly reports `Done 0 of 0` instead of the for-loop running once over the literal unexpanded glob string — same bug class `copy_images.sh` was already fixed for (see its `test_copy_images.sh` "unmatched glob doesn't leak" case).

### Step 4: Run the test again — confirm it passes

```bash
bash /home/renaud/projects/pokenini-icon/src/download-from-pokemon-db/test_convert.sh
```

Expected: `All assertions passed`, exit code 0.

### Step 5: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/download-from-pokemon-db/convert.sh src/download-from-pokemon-db/test_convert.sh
git commit -m "$(cat <<'EOF'
Parallelize convert.sh with xargs -P

cwebp was run one file at a time; -z 9 -m 6 -q 100 is CPU-heavy, so this
is a straightforward win across the available cores. Also fixes a missing
nullglob that made an empty source directory misbehave.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 3: Parallelize `convert_png_webp.sh`

**Files:**
- Modify: `src/convert_png_webp/convert_png_webp.sh`
- Create: `src/convert_png_webp/test_convert_png_webp.sh`

**Interfaces:**
- Consumes: env var `CONVERT_CONCURRENCY` (same convention as Task 2, default `$(nproc)`).

### Step 1: Write the test script

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

# convert_png_webp.sh reads/writes "images/..." relative to the cwd it's
# run from (see its hardcoded `directories` array) — unlike convert.sh, no
# need to copy it, just cd into the workdir before invoking it.
mkdir -p "$workdir/images/banner" "$workdir/images/big/regular" \
    "$workdir/images/big/shiny" "$workdir/images/small/regular" \
    "$workdir/images/small/shiny"

convert -size 4x4 xc:green PNG32:"$workdir/images/banner/a.png"
convert -size 4x4 xc:yellow PNG32:"$workdir/images/big/regular/b.png"

output=$(cd "$workdir" && CONVERT_CONCURRENCY=2 bash "$SCRIPT" 2>&1)

assert_file_exists "banner png converted" "$workdir/images/banner/a.webp"
assert_file_exists "big/regular png converted" "$workdir/images/big/regular/b.webp"

assert_matches "banner dir reports 1 done" "Done 1 images/banner, in [0-9]+s" "$output"
assert_matches "empty small/regular dir reports 0 done" "Done 0 images/small/regular, in [0-9]+s" "$output"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
TESTEOF
chmod +x /home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh
```

### Step 2: Run the test against the current (sequential) script — confirm the empty-directory case fails

```bash
bash /home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh
```

Expected: fails the same way as Task 2 Step 2 (no `nullglob`, empty directories mishandled).

### Step 3: Replace `convert_png_webp.sh` with the parallel version

```bash
cat > /home/renaud/projects/pokenini-icon/src/convert_png_webp/convert_png_webp.sh <<'SCRIPTEOF'
#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${CONVERT_CONCURRENCY:=$(nproc)}"

directories=("images/banner" "images/big/regular" "images/big/shiny" "images/small/regular" "images/small/shiny")

startAll=`date +%s`

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

for dir in "${directories[@]}"
do
    printf "Start %s\n" "$dir"

    DONE_FILE=$(mktemp)
    export DONE_FILE

    pngs=("$dir"/*.png)

    if [ "${#pngs[@]}" -gt 0 ]; then
        printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'convert_one "$@"' _ {}
    fi

    i=$(wc -l < "$DONE_FILE")
    rm -f "$DONE_FILE"

    runtime=$(((`date +%s`)-startAll))

    printf "Done %d %s, in %ds\n" "$i" "$dir" $runtime
done

exit
SCRIPTEOF
```

`SCRIPT_DIR` is computed but intentionally unused for path construction (same as the original — `directories` stays cwd-relative, matching how the Makefile invokes this script from the repo root).

### Step 4: Run the test again — confirm it passes

```bash
bash /home/renaud/projects/pokenini-icon/src/convert_png_webp/test_convert_png_webp.sh
```

Expected: `All assertions passed`, exit code 0.

### Step 5: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/convert_png_webp/convert_png_webp.sh src/convert_png_webp/test_convert_png_webp.sh
git commit -m "$(cat <<'EOF'
Parallelize convert_png_webp.sh with xargs -P

Same sequential-cwebp-per-file pattern as download-from-pokemon-db's
convert.sh; used by CI's "Regenerate small webp sprites" step.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 4: Parallelize `copy_images.sh`

**Files:**
- Modify: `src/copy_images/copy_images.sh`
- Modify: `src/copy_images/test_copy_images.sh` (append a new multi-file/concurrency scenario; existing assertions must keep passing unmodified)

**Interfaces:**
- Consumes: env var `COPY_CONCURRENCY` (default `$(nproc)`).
- Preserves exactly: final line `"Done %d (%d new) of %d %s, in %ds\n"`, per-file lines `"Reject %s: %s\n"` and `"Copy %s\n"` — asserted verbatim by the existing test.

### Step 1: Read the existing test to confirm the exact assertions that must keep passing

Already read during design — recorded here for reference, no action needed:
- `'Done 1 \(1 new\) of 1 foo,'` (regex-matched against combined output)
- `'*.webp'` must NOT appear in output when only `.png` exists in the source dir
- destination dirs get created on the fly if missing

### Step 2: Append a multi-file concurrency scenario to `test_copy_images.sh`

Insert this block right before the final `if [ "$failures" -ne 0 ]; then ... fi` block in `/home/renaud/projects/pokenini-icon/src/copy_images/test_copy_images.sh`:

```bash
# Multiple files processed under concurrency: 1 brand-new, 1 changed
# (differs from existing destination), 1 unchanged (must be skipped, not
# recopied) — exercises the parallel accounting (count/countNew/i) that
# used to be simple in-loop counters.
manyDir="$workdir/many/source"
mkdir -p "$manyDir" "$workdir/many/images/small/qux"
convert -size 4x4 xc:red PNG32:"$manyDir/new-one.png"
convert -size 4x4 xc:blue PNG32:"$manyDir/changed-one.png"
convert -size 4x4 xc:green PNG32:"$manyDir/unchanged-one.png"

# Pre-seed destinations for "changed" (different pixels) and "unchanged"
# (identical pixels) so compare -metric AE finds a real difference only
# for "changed-one". A separate reference copy of the unchanged file is
# kept outside the destination tree so a later `cmp` can prove the
# destination was never touched — reading binary PNG bytes through a
# bash string variable (e.g. `cat file` into `$(...)`) is unreliable
# (bash mangles NUL bytes), so this uses `cmp -s` on the files directly
# instead of a text-based assertion.
convert -size 4x4 xc:black PNG32:"$workdir/many/images/small/qux/changed-one.png"
convert -size 4x4 xc:green PNG32:"$workdir/many/images/small/qux/unchanged-one.png"
cp "$workdir/many/images/small/qux/unchanged-one.png" "$workdir/unchanged-one.reference.png"

output=$(cd "$workdir/many" && COPY_CONCURRENCY=3 bash "$SCRIPT" small "$manyDir" qux 4 4 2>&1)

assert_file_exists "new-one.png copied" "$workdir/many/images/small/qux/new-one.png"

if cmp -s "$workdir/unchanged-one.reference.png" "$workdir/many/images/small/qux/unchanged-one.png"; then
    printf "PASS %s\n" "unchanged-one.png is not recopied (bytes identical)"
else
    printf "FAIL %s\n" "unchanged-one.png is not recopied (bytes identical): destination was overwritten"
    failures=$((failures + 1))
fi

assert_matches "summary counts: 2 copied (1 new) of 3 total" \
    'Done 2 \(1 new\) of 3 qux,' "$output"
```

This uses the existing `assert_file_exists` and `assert_matches` helpers already defined earlier in the file — no new helpers needed.

### Step 3: Run the (updated) test against the current (sequential) `copy_images.sh` — confirm the new scenario passes

```bash
bash /home/renaud/projects/pokenini-icon/src/copy_images/test_copy_images.sh
```

Expected: all pass, including the new scenario (the sequential script is already correct — this step is establishing a baseline, not a red state; the real regression risk in this task is the *rewrite*, not the existing logic).

### Step 4: Replace `copy_images.sh` with the parallel version

```bash
cat > /home/renaud/projects/pokenini-icon/src/copy_images/copy_images.sh <<'SCRIPTEOF'
#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

category=$1
sourceDir=$2
file=$3
expectedWidth=$4
expectedHeight=$5

: "${COPY_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s (%sx%s)\n" "$file" "$expectedWidth" "$expectedHeight"

RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT

copy_one() {
    local image="$1"
    local filename=${image##*/}
    local destinationFile="images/$category/$file/$filename"
    local targetFile reason
    local countDifference=99999999999
    local isNew=0

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" "$expectedWidth" "$expectedHeight"); then
        targetFile="$destinationFile"
    else
        targetFile="review/$category/$file/$filename"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    mkdir -p "$(dirname "$targetFile")"

    if test -f "$targetFile"
    then
        countDifference=$(compare -metric AE "$image" "$targetFile" null: 2>&1)
    else
        isNew=1
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$targetFile"
        printf "Copy %s\n" "$filename"
        printf "COPY\n" >> "$RESULTS_FILE"
        [ "$isNew" -eq 1 ] && printf "NEW\n" >> "$RESULTS_FILE"
    fi

    printf "SEEN\n" >> "$RESULTS_FILE"
}
export -f copy_one
export SCRIPT_DIR category file expectedWidth expectedHeight RESULTS_FILE

images=("$sourceDir"/*.{png,webp})

if [ "${#images[@]}" -gt 0 ]; then
    printf '%s\0' "${images[@]}" | xargs -0 -P "$COPY_CONCURRENCY" -I{} bash -c 'copy_one "$@"' _ {}
fi

i=$(grep -c '^SEEN$' "$RESULTS_FILE")
count=$(grep -c '^COPY$' "$RESULTS_FILE")
countNew=$(grep -c '^NEW$' "$RESULTS_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d (%d new) of %d %s, in %ds\n" "$count" "$countNew" "$i" "$file" $runtime

exit
SCRIPTEOF
```

### Step 5: Run the test again — confirm everything (old + new scenarios) passes

```bash
bash /home/renaud/projects/pokenini-icon/src/copy_images/test_copy_images.sh
```

Expected: `All assertions passed`, exit code 0 — including the pre-existing "only-png" / "both extensions" / "new-dir" scenarios, unmodified.

### Step 6: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add src/copy_images/copy_images.sh src/copy_images/test_copy_images.sh
git commit -m "$(cat <<'EOF'
Parallelize copy_images.sh with xargs -P

validate_image.sh + ImageMagick compare per file was sequential; moved
accounting (count/countNew/i) from in-loop counters (impossible to share
across xargs -P children) to a tagged temp results file, counted after
the fact. Output format is unchanged — test_copy_images.sh's exact-text
assertions still pass, extended with a multi-file concurrency scenario.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Task 5: Cache `images/temp/` in the CI workflow

**Files:**
- Modify: `.github/workflows/update-images.yml`

**Interfaces:** None (CI-only change, no script interface affected).

### Step 1: Add the cache step

In `/home/renaud/projects/pokenini-icon/.github/workflows/update-images.yml`, insert a new step between "Install image tooling" and "Download, convert and copy \"big\" sprites from pokemondb.net" (i.e. right before the existing step that runs `make pdb_dl pdb_convert pdb_copy`):

```yaml
      - name: Cache pokemondb temp images
        uses: actions/cache@v4
        with:
          path: src/download-from-pokemon-db/images/temp
          key: pdb-images-temp-${{ github.run_id }}
          restore-keys: pdb-images-temp-
```

The full step list in the job should read, in order: Checkout, Install image tooling, **Cache pokemondb temp images** (new), Download/convert/copy "big" sprites, Download/copy "small" sprites, Regenerate "small" webp sprites, Fill in missing shiny placeholders, Check image dimensions, Open a PR.

### Step 2: Syntax-check the modified workflow file

```bash
python3 -c "
import yaml, sys
with open('/home/renaud/projects/pokenini-icon/.github/workflows/update-images.yml') as f:
    doc = yaml.safe_load(f)
steps = doc[True]['update-images']['steps']  # 'on' parses as boolean True in YAML 1.1
names = [s.get('name') for s in steps]
assert 'Cache pokemondb temp images' in names, names
idx_install = names.index('Install image tooling')
idx_cache = names.index('Cache pokemondb temp images')
idx_dl = names.index('Download, convert and copy \"big\" sprites from pokemondb.net')
assert idx_install < idx_cache < idx_dl, (idx_install, idx_cache, idx_dl)
print('OK: workflow parses and cache step is correctly ordered')
"
```

Expected: `OK: workflow parses and cache step is correctly ordered`.

### Step 3: Commit

```bash
cd /home/renaud/projects/pokenini-icon
git add .github/workflows/update-images.yml
git commit -m "$(cat <<'EOF'
Cache pokemondb images/temp between CI runs

src/download-from-pokemon-db/images/* is gitignored, so every
workflow_dispatch run of "Update Pokémon images" re-downloaded and
re-converted all ~3354 sprites from scratch — the scripts' own
skip-if-exists checks never got a chance to skip anything in CI. Caching
images/temp (covers both the downloaded .png and converted .webp) lets
repeat runs with an unchanged pokemons-list.txt skip nearly all of it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012BSS3na5dmEAWtzc2rkorz
EOF
)"
```

---

## Final check

After all 5 tasks are committed, run every test script in one pass to confirm nothing regressed:

```bash
cd /home/renaud/projects/pokenini-icon
for t in \
    src/download-from-pokemon-db/test_download-from-pokemondb.sh \
    src/download-from-pokemon-db/test_convert.sh \
    src/convert_png_webp/test_convert_png_webp.sh \
    src/copy_images/test_copy_images.sh \
    src/placeholders/test_make_them_all.sh \
    src/validate_image/test_validate_image.sh
do
    echo "=== $t ==="
    bash "$t" || echo "*** FAILED: $t ***"
done
```

Expected: every script prints `All assertions passed` (or equivalent existing pass message) and none print `FAILED`.

Optionally, time the real (network-hitting) pipeline before/after on the full list to confirm the actual wall-clock win:

```bash
cd /home/renaud/projects/pokenini-icon
time make pdb_dl
time make pdb_convert
time make pdb_copy
```
