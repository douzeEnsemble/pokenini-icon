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

assert_dir_exists() {
    local desc="$1" dir="$2"
    if [ -d "$dir" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to exist\n" "$desc" "$dir"
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

assert_dir_exists "destDir auto-created" "$dest2"
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
