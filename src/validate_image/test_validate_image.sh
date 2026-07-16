#!/bin/bash
set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
VALIDATE="$SCRIPT_DIR/validate_image.sh"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

failures=0

assert_valid() {
    local desc="$1" file="$2" width="$3" height="$4"
    output=$("$VALIDATE" "$file" "$width" "$height")
    status=$?
    if [ "$status" -ne 0 ]; then
        printf "FAIL %s: expected valid (exit 0), got exit %d, output: %s\n" "$desc" "$status" "$output"
        failures=$((failures + 1))
    else
        printf "PASS %s\n" "$desc"
    fi
}

assert_invalid() {
    local desc="$1" file="$2" width="$3" height="$4" expected_substring="$5"
    output=$("$VALIDATE" "$file" "$width" "$height")
    status=$?
    if [ "$status" -eq 0 ]; then
        printf "FAIL %s: expected invalid (nonzero exit), got exit 0\n" "$desc"
        failures=$((failures + 1))
    elif [[ "$output" != *"$expected_substring"* ]]; then
        printf "FAIL %s: expected output containing '%s', got '%s'\n" "$desc" "$expected_substring" "$output"
        failures=$((failures + 1))
    else
        printf "PASS %s\n" "$desc"
    fi
}

# Fixtures
convert -size 68x68 xc:red "$workdir/valid_small.png"
convert -size 256x256 xc:blue "$workdir/valid_big.png"
convert -size 64x64 xc:green "$workdir/wrong_dimensions.png"
touch "$workdir/empty.png"
echo "not an image" > "$workdir/corrupt.png"
cp "$workdir/valid_small.png" "$workdir/mislabeled.webp"

assert_valid   "correct 68x68 PNG"          "$workdir/valid_small.png"      68  68
assert_valid   "correct 256x256 PNG"        "$workdir/valid_big.png"        256 256
assert_invalid "wrong dimensions"           "$workdir/wrong_dimensions.png" 68  68  "bad dimensions"
assert_invalid "empty file"                 "$workdir/empty.png"            68  68  "empty file"
assert_invalid "corrupt file"                "$workdir/corrupt.png"          68  68  "unreadable"
assert_invalid "format doesn't match extension" "$workdir/mislabeled.webp"  68  68  "format mismatch"
assert_invalid "missing file"               "$workdir/does_not_exist.png"   68  68  "missing file"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
