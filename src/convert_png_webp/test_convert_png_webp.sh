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
