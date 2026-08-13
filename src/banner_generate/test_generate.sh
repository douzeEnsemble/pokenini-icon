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
# and output size matches the 578x325 canvas.
dir1="$workdir/dir1"
mkdir -p "$dir1/layers"
convert -size 578x325 xc:red PNG32:"$dir1/base.png"
convert -size 578x325 xc:none -fill blue -draw "rectangle 0,0 100,100" PNG32:"$dir1/layers/logoA.png"
convert -size 578x325 xc:none -fill green -draw "rectangle 200,200 300,300" PNG32:"$dir1/layers/logoB.png"
cat > "$dir1/banners.json" <<'JSON'
{
  "single": ["logoA"],
  "multi": ["logoA", "logoB"]
}
JSON
dest1="$workdir/dir1/out"

output1=$(BANNER_BASE_IMAGE="$dir1/base.png" BANNER_LAYERS_DIR="$dir1/layers" BANNER_CONFIG_FILE="$dir1/banners.json" CONVERT_CONCURRENCY=2 bash "$SCRIPT" "$dest1" 2>&1)

assert_file_exists "single.png created" "$dest1/single.png"
assert_file_exists "multi.png created" "$dest1/multi.png"
size_single=$(identify -format "%wx%h" "$dest1/single.png")
assert_equals "single.png keeps the 578x325 canvas" "578x325" "$size_single"
assert_matches "summary reports 2 of 2" "Generated 2 of 2 banners" "$output1"

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

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
