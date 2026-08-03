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
