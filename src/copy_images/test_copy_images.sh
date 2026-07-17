#!/bin/bash
set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$SCRIPT_DIR/copy_images.sh"

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

assert_not_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: output unexpectedly contains '%s'\n" "$desc" "$needle"
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

# A sourceDir with only one of the two extensions: the unmatched half of
# *.{png,webp} must not leak into the loop as a literal, un-expanded path.
# (images/<category>/<file>/ is pre-created, as it always is in the real repo —
# copy_images.sh itself never creates the accept-path destination dir.)
onlyPngDir="$workdir/only-png/source"
mkdir -p "$onlyPngDir"
mkdir -p "$workdir/only-png/images/small/foo"
convert -size 4x4 xc:red PNG32:"$onlyPngDir/foo.png"

output=$(cd "$workdir/only-png" && bash "$SCRIPT" small "$onlyPngDir" foo 4 4 2>&1)

assert_not_contains "unmatched *.webp glob doesn't leak into the output" '*.webp' "$output"
assert_matches "processes exactly the 1 real file, not a phantom glob entry" \
    'Done 1 \(1 new\) of 1 foo,' "$output"
assert_file_exists "the real png still gets copied to images/" \
    "$workdir/only-png/images/small/foo/foo.png"

# Sanity check: the common case (both extensions present) still works.
bothDir="$workdir/both/source"
mkdir -p "$bothDir"
mkdir -p "$workdir/both/images/small/bar"
convert -size 4x4 xc:red PNG32:"$bothDir/bar.png"
cwebp -quiet -q 100 "$bothDir/bar.png" -o "$bothDir/bar.webp" >/dev/null

output=$(cd "$workdir/both" && bash "$SCRIPT" small "$bothDir" bar 4 4 2>&1)

assert_file_exists "png still copied when both extensions are present" \
    "$workdir/both/images/small/bar/bar.png"
assert_file_exists "webp still copied when both extensions are present" \
    "$workdir/both/images/small/bar/bar.webp"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
