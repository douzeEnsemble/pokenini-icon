#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT="$REPO_SCRIPT_DIR/generate.sh"

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

# Scenario 1: single-layer and multi-layer banners composite correctly,
# and output size matches the 578x325 canvas. Pixel colors are asserted at
# known coordinates to prove layers are actually drawn (not silently
# dropped), and an overlap case proves last-listed-layer-wins ordering.
#
# Canvas: 578x325, base=red everywhere.
#   logoA = blue rectangle at (0,0)-(100,100)
#   logoB = green rectangle at (200,200)-(300,300)      [non-overlapping with A]
#   logoC = yellow rectangle at (50,50)-(150,150)        [overlaps A at (75,75)]
dir1="$workdir/dir1"
mkdir -p "$dir1/layers"
convert -size 578x325 xc:red PNG32:"$dir1/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir1/layers/logoA.png"
convert -size 578x325 xc:none -fill green -draw "rectangle 200,200 300,300" PNG32:"$dir1/layers/logoB.png"
convert -size 578x325 xc:none -fill yellow -draw "rectangle 50,50 150,150" PNG32:"$dir1/layers/logoC.png"
cat > "$dir1/banners.json" <<'JSON'
{
  "single": ["logoA"],
  "multi": ["logoA", "logoB"],
  "overlap": ["logoA", "logoC"]
}
JSON
dest1="$workdir/dir1/out"

output1=$(BANNER_BASE_IMAGE="$dir1/base.png" BANNER_LAYERS_DIR="$dir1/layers" BANNER_CONFIG_FILE="$dir1/banners.json" CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dest1" 2>&1)

assert_file_exists "single.png created" "$dest1/single.png"
assert_file_exists "multi.png created" "$dest1/multi.png"
size_single=$(identify -format "%wx%h" "$dest1/single.png")
assert_equals "single.png keeps the 578x325 canvas" "578x325" "$size_single"
assert_matches "summary reports 3 of 3" "Generated 3 of 3 banners" "$output1"
assert_matches "GENERATED line is printed for each newly generated slug" "GENERATED: single" "$output1"
assert_matches "GENERATED line is printed for each newly generated slug (multi)" "GENERATED: multi" "$output1"
assert_matches "GENERATED line is printed for each newly generated slug (overlap)" "GENERATED: overlap" "$output1"

pixel() {
    identify -format '%[pixel:p{'"$2"','"$3"'}]' "$1"
}

assert_equals "multi.png is blue at logoA's location" "srgb(0,0,255)" "$(pixel "$dest1/multi.png" 50 50)"
assert_equals "multi.png is green at logoB's location" "srgb(0,128,0)" "$(pixel "$dest1/multi.png" 250 250)"
assert_equals "multi.png is red where no layer touches" "srgb(255,0,0)" "$(pixel "$dest1/multi.png" 400 300)"

# Overlap case: logoC is listed after logoA, so where they overlap,
# logoC (yellow) must win over logoA (blue).
assert_equals "overlap.png is yellow where logoC overlaps logoA (last layer wins)" "srgb(255,255,0)" "$(pixel "$dest1/overlap.png" 75 75)"
assert_equals "overlap.png is still blue where only logoA is drawn" "srgb(0,0,255)" "$(pixel "$dest1/overlap.png" 10 10)"

# Scenario 2: a banner referencing a missing layer fails loudly.
dir2="$workdir/dir2"
mkdir -p "$dir2/layers"
convert -size 578x325 xc:red PNG32:"$dir2/base.png"
cat > "$dir2/banners.json" <<'JSON'
{
  "broken": ["does-not-exist"]
}
JSON
dest2="$workdir/dir2/out"

set +e
output2=$(BANNER_BASE_IMAGE="$dir2/base.png" BANNER_LAYERS_DIR="$dir2/layers" BANNER_CONFIG_FILE="$dir2/banners.json" bash "$SCRIPT" "$dest2" 2>&1)
exit_code2=$?
set -e

assert_equals "missing layer exits non-zero" "1" "$exit_code2"
assert_matches "missing layer error names the layer and the banner" "ERROR: layer 'does-not-exist' referenced by banner 'broken' not found" "$output2"

# Scenario 3: empty config -> succeeds, generates nothing.
dir3="$workdir/dir3"
mkdir -p "$dir3/layers"
convert -size 578x325 xc:red PNG32:"$dir3/base.png"
printf '{}' > "$dir3/banners.json"
dest3="$workdir/dir3/out"

output3=$(BANNER_BASE_IMAGE="$dir3/base.png" BANNER_LAYERS_DIR="$dir3/layers" BANNER_CONFIG_FILE="$dir3/banners.json" bash "$SCRIPT" "$dest3" 2>&1)

assert_matches "empty config reports 0 of 0" "Generated 0 of 0 banners" "$output3"

# Scenario 4: missing base image fails loudly before touching destDir.
dir4="$workdir/dir4"
mkdir -p "$dir4/layers"
printf '{}' > "$dir4/banners.json"
dest4="$workdir/dir4/out"

set +e
output4=$(BANNER_BASE_IMAGE="$dir4/base.png" BANNER_LAYERS_DIR="$dir4/layers" BANNER_CONFIG_FILE="$dir4/banners.json" bash "$SCRIPT" "$dest4" 2>&1)
exit_code4=$?
set -e

assert_equals "missing base image exits non-zero" "1" "$exit_code4"
assert_matches "missing base image error is clear" "ERROR: base image not found" "$output4"

# Scenario 5: a banner referencing a present-but-corrupt layer fails loudly
# (a `convert` failure inside the parallel worker must not be swallowed).
dir5="$workdir/dir5"
mkdir -p "$dir5/layers"
convert -size 578x325 xc:red PNG32:"$dir5/base.png"
printf 'not a valid png' > "$dir5/layers/corrupt.png"
cat > "$dir5/banners.json" <<'JSON'
{
  "brokenconvert": ["corrupt"]
}
JSON
dest5="$workdir/dir5/out"

set +e
output5=$(BANNER_BASE_IMAGE="$dir5/base.png" BANNER_LAYERS_DIR="$dir5/layers" BANNER_CONFIG_FILE="$dir5/banners.json" bash "$SCRIPT" "$dest5" 2>&1)
exit_code5=$?
set -e

assert_equals "corrupt layer (convert failure) exits non-zero" "1" "$exit_code5"

# Scenario 6: a slug with an empty layer list ([]) must hard-fail rather than
# silently compositing a blank (base-only) image. This guards against the
# real failure mode where `banners.json` has real slugs still seeded to []
# and a run would overwrite existing artwork with transparent placeholders.
dir6="$workdir/dir6"
mkdir -p "$dir6/layers"
convert -size 578x325 xc:red PNG32:"$dir6/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir6/layers/logoA.png"
cat > "$dir6/banners.json" <<'JSON'
{
  "good": ["logoA"],
  "noimage": []
}
JSON
dest6="$workdir/dir6/out"

set +e
output6=$(BANNER_BASE_IMAGE="$dir6/base.png" BANNER_LAYERS_DIR="$dir6/layers" BANNER_CONFIG_FILE="$dir6/banners.json" bash "$SCRIPT" "$dest6" 2>&1)
exit_code6=$?
set -e

assert_equals "empty layer list exits non-zero" "1" "$exit_code6"
assert_matches "empty layer list error names the offending slug" "ERROR: the following banner\(s\) have an empty layer list.*noimage" "$output6"
if [ -f "$dest6/noimage.png" ]; then
    printf "FAIL empty layer list must not write a blank output file: %s exists\n" "$dest6/noimage.png"
    failures=$((failures + 1))
else
    printf "PASS empty layer list does not write a blank output file\n"
fi

# Scenario 7: a missing config file fails loudly instead of succeeding with
# "Generated 0 of 0 banners".
dir7="$workdir/dir7"
mkdir -p "$dir7/layers"
convert -size 578x325 xc:red PNG32:"$dir7/base.png"
dest7="$workdir/dir7/out"

set +e
output7=$(BANNER_BASE_IMAGE="$dir7/base.png" BANNER_LAYERS_DIR="$dir7/layers" BANNER_CONFIG_FILE="$dir7/does-not-exist.json" bash "$SCRIPT" "$dest7" 2>&1)
exit_code7=$?
set -e

assert_equals "missing config file exits non-zero" "1" "$exit_code7"
assert_matches "missing config file error is clear" "ERROR: banner config file not found" "$output7"

# Scenario 8: malformed (syntactically broken) JSON fails loudly instead of
# succeeding with "Generated 0 of 0 banners" (process substitution previously
# hid jq's exit status from `set -e`).
dir8="$workdir/dir8"
mkdir -p "$dir8/layers"
convert -size 578x325 xc:red PNG32:"$dir8/base.png"
printf '{ this is not valid json' > "$dir8/banners.json"
dest8="$workdir/dir8/out"

set +e
output8=$(BANNER_BASE_IMAGE="$dir8/base.png" BANNER_LAYERS_DIR="$dir8/layers" BANNER_CONFIG_FILE="$dir8/banners.json" bash "$SCRIPT" "$dest8" 2>&1)
exit_code8=$?
set -e

assert_equals "malformed JSON config exits non-zero" "1" "$exit_code8"
assert_matches "malformed JSON config error is clear" "ERROR: banner config file is not valid JSON" "$output8"

# Scenario 9: a non-array value for a slug (e.g. a typo like "weird": "a"
# instead of "weird": ["a"]) fails loudly instead of silently producing a
# base-only image for that slug.
dir9="$workdir/dir9"
mkdir -p "$dir9/layers"
convert -size 578x325 xc:red PNG32:"$dir9/base.png"
cat > "$dir9/banners.json" <<'JSON'
{
  "weird": "a"
}
JSON
dest9="$workdir/dir9/out"

set +e
output9=$(BANNER_BASE_IMAGE="$dir9/base.png" BANNER_LAYERS_DIR="$dir9/layers" BANNER_CONFIG_FILE="$dir9/banners.json" bash "$SCRIPT" "$dest9" 2>&1)
exit_code9=$?
set -e

assert_equals "non-array slug value exits non-zero" "1" "$exit_code9"
assert_matches "non-array slug value error is clear" "ERROR: banner config file must be an object mapping each slug to an array of layer-name strings" "$output9"

# Scenario 10: a slug whose output PNG already exists is skipped entirely
# (not regenerated) -- this lets a run avoid re-doing work for banners
# that haven't changed since the last run.
dir10="$workdir/dir10"
mkdir -p "$dir10/layers" "$dir10/out"
convert -size 578x325 xc:red PNG32:"$dir10/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir10/layers/logoA.png"
cat > "$dir10/banners.json" <<'JSON'
{
  "existing": ["logoA"]
}
JSON
dest10="$dir10/out"
# Pre-create the output as something the real composite would NOT produce
# (solid green, not red+blue), so "untouched" is provable, not coincidental.
convert -size 578x325 xc:green PNG32:"$dest10/existing.png"
preHash=$(md5sum "$dest10/existing.png" | awk '{print $1}')

output10=$(BANNER_BASE_IMAGE="$dir10/base.png" BANNER_LAYERS_DIR="$dir10/layers" BANNER_CONFIG_FILE="$dir10/banners.json" bash "$SCRIPT" "$dest10" 2>&1)
postHash=$(md5sum "$dest10/existing.png" | awk '{print $1}')

assert_equals "existing banner file is left byte-for-byte untouched" "$preHash" "$postHash"
assert_matches "skip is logged for the existing banner" "SKIP: existing already exists" "$output10"
assert_matches "summary reports 0 generated, 1 skipped" "Generated 0 of 1 banners \(1 already existed, skipped\)" "$output10"
if [[ "$output10" == *"GENERATED:"* ]]; then
    printf "FAIL a skipped banner must not print a GENERATED: line: got:\n%s\n" "$output10"
    failures=$((failures + 1))
else
    printf "PASS no GENERATED: line is printed for a skipped banner\n"
fi

# Scenario 11: a slug whose output PNG already exists (so it would be
# skipped) but whose config now references a layer that doesn't exist
# must still fail loudly -- the skip check must never bypass layer
# validation, or a layer renamed/removed after a banner was generated
# would go undetected forever.
dir11="$workdir/dir11"
mkdir -p "$dir11/layers" "$dir11/out"
convert -size 578x325 xc:red PNG32:"$dir11/base.png"
cat > "$dir11/banners.json" <<'JSON'
{
  "stale": ["does-not-exist-anymore"]
}
JSON
dest11="$dir11/out"
convert -size 578x325 xc:green PNG32:"$dest11/stale.png"

set +e
output11=$(BANNER_BASE_IMAGE="$dir11/base.png" BANNER_LAYERS_DIR="$dir11/layers" BANNER_CONFIG_FILE="$dir11/banners.json" bash "$SCRIPT" "$dest11" 2>&1)
exit_code11=$?
set -e

assert_equals "stale layer reference on an already-generated banner still exits non-zero" "1" "$exit_code11"
assert_matches "stale layer reference error names the layer and the banner" "ERROR: layer 'does-not-exist-anymore' referenced by banner 'stale' not found" "$output11"

# Scenario 12: no leftover hidden temp file after a normal successful
# generation -- proves the atomic temp-file-then-rename write cleans up
# after itself instead of littering $destDir.
dir12="$workdir/dir12"
mkdir -p "$dir12/layers"
convert -size 578x325 xc:red PNG32:"$dir12/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir12/layers/logoA.png"
cat > "$dir12/banners.json" <<'JSON'
{
  "clean": ["logoA"]
}
JSON
dest12="$dir12/out"

BANNER_BASE_IMAGE="$dir12/base.png" BANNER_LAYERS_DIR="$dir12/layers" BANNER_CONFIG_FILE="$dir12/banners.json" bash "$SCRIPT" "$dest12" > /dev/null 2>&1

leftoverTempFiles=$(find "$dest12" -maxdepth 1 -name '.clean.*.png' 2>/dev/null)
assert_equals "no leftover hidden temp file after a successful generation" "" "$leftoverTempFiles"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
