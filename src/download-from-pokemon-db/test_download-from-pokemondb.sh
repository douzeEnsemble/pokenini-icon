#!/bin/bash
set -u

REPO_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_NAME="download-from-pokemondb.sh"

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

assert_file_not_exists() {
    local desc="$1" file="$2"
    if [ ! -f "$file" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected %s to NOT exist\n" "$desc" "$file"
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

assert_equals() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf "PASS %s\n" "$desc"
    else
        printf "FAIL %s: expected '%s', got '%s'\n" "$desc" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

# The script keys its output paths off its own location (SCRIPT_DIR), not
# the caller's cwd, so it's copied into an isolated workdir to run — this
# keeps the test from writing into the real repo's images/temp/.
cp "$REPO_SCRIPT_DIR/$SCRIPT_NAME" "$workdir/$SCRIPT_NAME"

# Fake wget: "good*" source names succeed with fake image bytes, "bad*"
# source names simulate a 404 (empty output), matching how the real script
# detects failure (-s check on the downloaded file).
# The output includes the sourceFileName from the URL to allow testing which
# source won in race conditions.
mkdir -p "$workdir/bin"
cat > "$workdir/bin/wget" <<'EOF'
#!/bin/bash
out=""
url=""
while [ $# -gt 0 ]; do
    case "$1" in
        -O) out="$2"; shift 2 ;;
        --no-cache|-q) shift ;;
        *) url="$1"; shift ;;
    esac
done
if [[ "$url" == *"/bad"* ]]; then
    : > "$out"
else
    # Extract sourceFileName from URL for identification in tests
    sourceFileName=$(echo "$url" | rev | cut -d'/' -f1 | rev | sed 's/\.png$//')
    printf 'fake-image-bytes-%s' "$sourceFileName" > "$out"
fi
EOF
chmod +x "$workdir/bin/wget"

list="$workdir/list.txt"
cat > "$list" <<'EOF'
good1,home,good1
bad1,home,bad1
good2,home,good2
EOF
list_before=$(cat "$list")

output=$(cd "$workdir" && PATH="$workdir/bin:$PATH" DOWNLOAD_CONCURRENCY=3 \
    bash "./$SCRIPT_NAME" "$list" rs 2>&1)

list_after=$(cat "$list")

assert_equals "input list file is never mutated by the script" "$list_before" "$list_after"

assert_file_exists "good1 regular downloaded" "$workdir/images/temp/regular/good1.png"
assert_file_exists "good1 shiny downloaded" "$workdir/images/temp/shiny/good1.png"
assert_file_exists "good2 regular downloaded" "$workdir/images/temp/regular/good2.png"
assert_file_exists "good2 shiny downloaded" "$workdir/images/temp/shiny/good2.png"

assert_file_not_exists "bad1 regular not kept (empty download removed)" "$workdir/images/temp/regular/bad1.png"
assert_file_not_exists "bad1 shiny not kept (empty download removed)" "$workdir/images/temp/shiny/bad1.png"

failedRegular=$(cat "$workdir/report_failed_regular.txt")
failedShiny=$(cat "$workdir/report_failed_shiny.txt")

assert_matches "bad1 recorded in failed-regular report" "bad1,home,bad1" "$failedRegular"
assert_matches "bad1 recorded in failed-shiny report" "bad1,home,bad1" "$failedShiny"


# 3 list entries, both regular+shiny requested ("rs") -> totalCount is
# doubled (count * 2 variants) = 6, regardless of the 1 failure on each
# side — matches the original script's (buggy-but-unchanged) semantics of
# not subtracting failures from totalCount, just now actually computing a
# real number instead of always reading back 0.
assert_matches "final summary line printed" "Done 6, 1\+1, in [0-9]+s" "$output"


# === Test 2: Duplicate targets (deduplication) ===
# Two different sources targeting the same filename.
# The deduped script should only download once, using the FIRST occurrence.
# This test runs with higher concurrency to stress the race condition.

list2="$workdir/list2.txt"
cat > "$list2" <<'EOF'
sourceA,home,shared
sourceB,home,shared
sourceC,home,other
EOF

output2=$(cd "$workdir" && PATH="$workdir/bin:$PATH" DOWNLOAD_CONCURRENCY=4 \
    bash "./$SCRIPT_NAME" "$list2" r 2>&1)

# Only one download per unique target, so 2 unique targets (shared, other)
assert_file_exists "shared target downloaded" "$workdir/images/temp/regular/shared.png"
assert_file_exists "other target downloaded" "$workdir/images/temp/regular/other.png"

# Verify the FIRST source (sourceA) won the race for the shared target
shared_content=$(cat "$workdir/images/temp/regular/shared.png")
assert_equals "first source wins race for duplicate target" "fake-image-bytes-sourceA" "$shared_content"

# The other target should have its source content
other_content=$(cat "$workdir/images/temp/regular/other.png")
assert_equals "unique target has correct content" "fake-image-bytes-sourceC" "$other_content"

# Summary should report 2 unique targets (not 3 raw entries) when both r and s not both requested
assert_matches "summary counts deduplicated targets" "Done 2, 0\+0, in [0-9]+s" "$output2"

if [ "$failures" -ne 0 ]; then
    printf "\n%d assertion(s) failed\n" "$failures"
    exit 1
fi

printf "\nAll assertions passed\n"
exit 0
