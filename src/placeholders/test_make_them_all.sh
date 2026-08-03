#!/bin/bash
set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

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

assert_file_missing() {
    local desc="$1" file="$2"
    if [ ! -f "$file" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to NOT exist\n" "$desc" "$file"
        failures=$((failures + 1))
    fi
}

# Run the real script from a sandbox that mirrors its expected
# src/placeholders/../../images/<dir>/{regular,shiny} layout, so it needs
# no test-only seam and cannot touch the repo's real images/ tree.
mkdir -p "$workdir/src/placeholders"
cp "$SCRIPT_DIR/make_them_all.sh" "$workdir/src/placeholders/make_them_all.sh"

regularDir="$workdir/images/small/regular"
shinyDir="$workdir/images/small/shiny"
mkdir -p "$regularDir" "$shinyDir"

# Real icons always carry an alpha channel (transparent background); the script's
# `matte:-` conversion step requires one too, so fixtures must have one.
# Already has a shiny counterpart: must be left untouched, no placeholder generated.
convert -size 4x4 xc:blue PNG32:"$regularDir/has-shiny.png"
convert -size 4x4 xc:blue PNG32:"$shinyDir/has-shiny.png"

# Missing its shiny counterpart: must get a generated placeholder published.
convert -size 4x4 xc:red PNG32:"$regularDir/missing-shiny.png"

bash "$workdir/src/placeholders/make_them_all.sh" s > "$workdir/output.txt"

assert_file_missing "skips icon that already has a shiny counterpart" \
    "$workdir/src/placeholders/tmp/small/shiny/has-shiny.png"
assert_file_exists "publishes generated placeholder as PNG in images/" \
    "$shinyDir/missing-shiny.png"
assert_file_missing "does not convert to WEBP (that's img_convert's job, run once afterwards)" \
    "$shinyDir/missing-shiny.webp"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
