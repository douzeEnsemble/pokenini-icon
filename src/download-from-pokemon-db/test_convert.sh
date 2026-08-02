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
