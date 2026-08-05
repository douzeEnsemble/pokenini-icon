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

mkdir -p "$workdir/images/banner/large" "$workdir/images/pokemon/big/regular" \
    "$workdir/images/pokemon/big/shiny" "$workdir/images/pokemon/small/regular" \
    "$workdir/images/pokemon/small/shiny"

convert -size 4x4 xc:green PNG32:"$workdir/images/banner/large/a.png"
convert -size 4x4 xc:yellow PNG32:"$workdir/images/pokemon/big/regular/b.png"

# A pre-existing .webp must be left untouched (skip-if-exists) — copy_images.sh
# is responsible for invalidating a stale .webp when its .png actually
# changes, so that an unrelated re-run doesn't touch every image and turn
# every file into a spurious git diff.
convert -size 4x4 xc:purple PNG32:"$workdir/images/pokemon/small/shiny/c.png"
printf 'sentinel-content' > "$workdir/images/pokemon/small/shiny/c.webp"

output=$(cd "$workdir" && CONVERT_CONCURRENCY=2 bash "$SCRIPT" 2>&1)

assert_file_exists "banner png converted" "$workdir/images/banner/large/a.webp"
assert_file_exists "big/regular png converted" "$workdir/images/pokemon/big/regular/b.webp"

sentinelContent=$(cat "$workdir/images/pokemon/small/shiny/c.webp")
if [ "$sentinelContent" = "sentinel-content" ]; then
    printf "PASS %s\n" "pre-existing webp is left untouched"
else
    printf "FAIL %s\n" "pre-existing webp is left untouched: was overwritten"
    failures=$((failures + 1))
fi

assert_matches "banner dir reports 1 of 1 done" "Done 1 of 1 images/banner/large, in [0-9]+s" "$output"
assert_matches "empty small/regular dir reports 0 of 0 done" "Done 0 of 0 images/pokemon/small/regular, in [0-9]+s" "$output"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
