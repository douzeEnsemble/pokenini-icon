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

assert_file_missing() {
    local desc="$1" file="$2"
    if [ ! -f "$file" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to NOT exist\n" "$desc" "$file"
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
mkdir -p "$workdir/only-png/images/pokemon/small/foo"
convert -size 4x4 xc:red PNG32:"$onlyPngDir/foo.png"

output=$(cd "$workdir/only-png" && bash "$SCRIPT" pokemon/small "$onlyPngDir" foo 4 4 2>&1)

assert_not_contains "unmatched *.webp glob doesn't leak into the output" '*.webp' "$output"
assert_matches "processes exactly the 1 real file, not a phantom glob entry" \
    'Done 1 \(1 new\) of 1 foo,' "$output"
assert_file_exists "the real png still gets copied to images/" \
    "$workdir/only-png/images/pokemon/small/foo/foo.png"

# Sanity check: the common case (both extensions present) still works.
bothDir="$workdir/both/source"
mkdir -p "$bothDir"
mkdir -p "$workdir/both/images/pokemon/small/bar"
convert -size 4x4 xc:red PNG32:"$bothDir/bar.png"
cwebp -quiet -q 100 "$bothDir/bar.png" -o "$bothDir/bar.webp" >/dev/null

output=$(cd "$workdir/both" && bash "$SCRIPT" pokemon/small "$bothDir" bar 4 4 2>&1)

assert_file_exists "png still copied when both extensions are present" \
    "$workdir/both/images/pokemon/small/bar/bar.png"
assert_file_exists "webp still copied when both extensions are present" \
    "$workdir/both/images/pokemon/small/bar/bar.webp"

# Accept-path destination dir not pre-created: unlike the real repo (where
# images/<size>/<file>/ always already exists), a brand-new category/file
# combination must still get its destination directory created on the fly.
newDirTest="$workdir/new-dir/source"
mkdir -p "$newDirTest"
convert -size 4x4 xc:red PNG32:"$newDirTest/baz.png"

output=$(cd "$workdir/new-dir" && bash "$SCRIPT" pokemon/small "$newDirTest" baz 4 4 2>&1)

assert_file_exists "accept-path destination dir is created even if it didn't pre-exist" \
    "$workdir/new-dir/images/pokemon/small/baz/baz.png"

# Multiple files processed under concurrency: 1 brand-new, 1 changed
# (differs from existing destination), 1 unchanged (must be skipped, not
# recopied) — exercises the parallel accounting (count/countNew/i) that
# used to be simple in-loop counters.
manyDir="$workdir/many/source"
mkdir -p "$manyDir" "$workdir/many/images/pokemon/small/qux"
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
convert -size 4x4 xc:black PNG32:"$workdir/many/images/pokemon/small/qux/changed-one.png"
convert -size 4x4 xc:green PNG32:"$workdir/many/images/pokemon/small/qux/unchanged-one.png"
cp "$workdir/many/images/pokemon/small/qux/unchanged-one.png" "$workdir/unchanged-one.reference.png"

# Pre-existing .webp siblings: "changed-one"'s must be dropped since its .png
# is about to be overwritten with different content (it would otherwise go
# stale, silently mismatching the new png). "unchanged-one"'s must survive,
# since its .png is never touched.
printf 'stale-webp' > "$workdir/many/images/pokemon/small/qux/changed-one.webp"
printf 'current-webp' > "$workdir/many/images/pokemon/small/qux/unchanged-one.webp"

output=$(cd "$workdir/many" && COPY_CONCURRENCY=3 bash "$SCRIPT" pokemon/small "$manyDir" qux 4 4 2>&1)

assert_file_exists "new-one.png copied" "$workdir/many/images/pokemon/small/qux/new-one.png"

assert_file_missing "stale webp sibling of an overwritten png is dropped" \
    "$workdir/many/images/pokemon/small/qux/changed-one.webp"
assert_file_exists "webp sibling of an untouched png is left alone" \
    "$workdir/many/images/pokemon/small/qux/unchanged-one.webp"

if cmp -s "$workdir/unchanged-one.reference.png" "$workdir/many/images/pokemon/small/qux/unchanged-one.png"; then
    printf "PASS %s\n" "unchanged-one.png is not recopied (bytes identical)"
else
    printf "FAIL %s\n" "unchanged-one.png is not recopied (bytes identical): destination was overwritten"
    failures=$((failures + 1))
fi

assert_matches "summary counts: 2 copied (1 new) of 3 total" \
    'Done 2 \(1 new\) of 3 qux,' "$output"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
