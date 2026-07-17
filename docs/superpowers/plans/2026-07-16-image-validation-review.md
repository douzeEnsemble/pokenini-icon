# Image Validation Before Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route images produced by the automated sprite pipeline into `images/` only if they pass validation (readable, correct format, correct dimensions, non-empty); invalid images go to a new git-tracked `review/` directory instead, mirroring `images/`'s layout.

**Architecture:** A new shared shell script `src/validate_image/validate_image.sh` encapsulates the validity check (exit 0/1 + reason on stdout). The two existing copy scripts that write into `images/` — `src/download-from-pokemon-db/cp.sh` (big, 256×256) and `src/cut-mbcmechachu-sprites/cp.sh` (small=68×68 / big=256×256, size-parameterized) — call it per-file before their existing copy-if-changed logic, and redirect the destination to `review/<same relative path>` on failure. `update-images.yml` gets `review` added to `add-paths` so those changes surface in the auto-generated PR.

**Tech Stack:** Bash, ImageMagick (`identify`), GitHub Actions (YAML).

## Global Constraints

- Validity = file exists, non-zero size, `identify`-decodable, decoded format matches the file extension, pixel dimensions exactly match the expected width/height for the image's category (256×256 for `big`, 68×68 for `small`).
- `review/` is a normal git-tracked directory (not gitignored), mirroring `images/<size>/<regular|shiny>/`.
- Out of scope: `images/banner` (hand-maintained, not pipeline-sourced) and `src/placeholders` (writes to a scratch `tmp/` dir, not into `images/`). `make check_size` stays unchanged.
- No existing automated test framework covers these bash scripts (the only test suite in the repo is the Python/pytest one under `src/cut-mbcmechachu-sprites/tests`, for a different component). Verification here is a mix of a small self-contained bash test script (Task 1) and manual fixture-based runs (Tasks 2–3), always cleaned up so no test artifacts get committed to `images/` or `review/`.
- Full design context: `docs/superpowers/specs/2026-07-16-image-validation-review-design.md`.

---

### Task 1: Shared validation script

**Files:**
- Create: `src/validate_image/validate_image.sh`
- Create: `src/validate_image/test_validate_image.sh`

**Interfaces:**
- Produces: `src/validate_image/validate_image.sh <file> <expected_width> <expected_height>` — exit 0 and no stdout output if valid; exit 1 with a one-line reason on stdout if invalid. Depended on by Task 2 and Task 3.

- [ ] **Step 1: Confirm ImageMagick is installed locally**

Run: `identify -version`

Expected: version banner printed. If instead you see `command not found`, install it first (matches what CI does in `update-images.yml`):

```bash
sudo apt-get update && sudo apt-get install -y imagemagick webp
```

- [ ] **Step 2: Write the test script**

Create `src/validate_image/test_validate_image.sh`:

```bash
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
```

```bash
chmod +x src/validate_image/test_validate_image.sh
```

- [ ] **Step 3: Run the test script to verify it fails**

Run: `bash src/validate_image/test_validate_image.sh`

Expected: fails immediately — `src/validate_image/validate_image.sh: No such file or directory` (the script doesn't exist yet).

- [ ] **Step 4: Write the validator**

Create `src/validate_image/validate_image.sh`:

```bash
#!/bin/bash

file="$1"
expectedWidth="$2"
expectedHeight="$3"

if [ ! -f "$file" ]; then
    echo "missing file"
    exit 1
fi

if [ ! -s "$file" ]; then
    echo "empty file"
    exit 1
fi

info=$(identify -format "%m %w %h" "$file" 2>/dev/null)
if [ -z "$info" ]; then
    echo "unreadable/corrupt"
    exit 1
fi

format=$(echo "$info" | awk '{print $1}')
width=$(echo "$info" | awk '{print $2}')
height=$(echo "$info" | awk '{print $3}')

extension="${file##*.}"
extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

case "$extension" in
    png)
        expectedFormat="PNG"
        ;;
    webp)
        expectedFormat="WEBP"
        ;;
    jpg|jpeg)
        expectedFormat="JPEG"
        ;;
    *)
        echo "unsupported extension: .$extension"
        exit 1
        ;;
esac

if [ "$format" != "$expectedFormat" ]; then
    echo "format mismatch: expected $expectedFormat, got $format"
    exit 1
fi

if [ "$width" -ne "$expectedWidth" ] || [ "$height" -ne "$expectedHeight" ]; then
    echo "bad dimensions: ${width}x${height} (expected ${expectedWidth}x${expectedHeight})"
    exit 1
fi

exit 0
```

```bash
chmod +x src/validate_image/validate_image.sh
```

- [ ] **Step 5: Run the test script to verify it passes**

Run: `bash src/validate_image/test_validate_image.sh`

Expected:
```
PASS correct 68x68 PNG
PASS correct 256x256 PNG
PASS wrong dimensions
PASS empty file
PASS corrupt file
PASS format doesn't match extension
PASS missing file

All assertions passed
```

- [ ] **Step 6: Commit**

```bash
git add src/validate_image/validate_image.sh src/validate_image/test_validate_image.sh
git commit -m "Add shared image validation script"
```

---

### Task 2: Wire validation into the PokemonDB copy script (big/256×256)

**Files:**
- Modify: `src/download-from-pokemon-db/cp.sh`

**Interfaces:**
- Consumes: `src/validate_image/validate_image.sh <file> <expected_width> <expected_height>` from Task 1.

- [ ] **Step 1: Read the current script**

`src/download-from-pokemon-db/cp.sh` currently copies every changed image straight to `images/big/$file/$filename`. Confirm this by reading it — the loop body is:

```bash
for image in "$SCRIPT_DIR/images/temp/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/big/$file/$filename"

    countDifference=99999999999
    if test -f "$destinationFile"
    then
        countDifference=$(compare -metric AE "$image" "$destinationFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$destinationFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done
```

- [ ] **Step 2: Edit the loop to validate before copying**

Replace that loop body with:

```bash
for image in "$SCRIPT_DIR/images/temp/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/big/$file/$filename"

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" 256 256); then
        targetFile="$destinationFile"
    else
        targetFile="review/big/$file/$filename"
        mkdir -p "$(dirname "$targetFile")"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    countDifference=99999999999
    if test -f "$targetFile"
    then
        countDifference=$(compare -metric AE "$image" "$targetFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$targetFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done
```

- [ ] **Step 3: Manually verify with a harmless fixture (does not touch real pokemon data)**

Use a fake identifier (`9999-test`) so nothing collides with real sprites, and clean up afterward.

```bash
mkdir -p src/download-from-pokemon-db/images/temp/regular
convert -size 256x256 xc:blue src/download-from-pokemon-db/images/temp/regular/9999-test-valid.png
convert -size 100x100 xc:red src/download-from-pokemon-db/images/temp/regular/9999-test-invalid.png

bash src/download-from-pokemon-db/cp.sh regular
```

Glob expansion is alphabetical, so `9999-test-invalid.png` is processed before `9999-test-valid.png`. The copy-if-changed step still runs after a reject (it just now targets `review/`), so expect both a `Reject` line and a `Copy` line for the invalid file:

```
Reject 9999-test-invalid.png: bad dimensions: 100x100 (expected 256x256)
Copy 9999-test-invalid.png
Copy 9999-test-valid.png
```

Verify placement:
```bash
ls images/big/regular/9999-test-valid.png        # exists
ls review/big/regular/9999-test-invalid.png       # exists
ls images/big/regular/9999-test-invalid.png       # does NOT exist (ls: no such file)
```

- [ ] **Step 4: Clean up the fixture so nothing spurious gets committed**

```bash
rm -f images/big/regular/9999-test-valid.png
rm -f review/big/regular/9999-test-invalid.png
rmdir review/big/regular review/big 2>/dev/null || true
rm -rf src/download-from-pokemon-db/images/temp/regular
git status --short images/ review/
```

Expected: `git status --short images/ review/` prints nothing (clean).

- [ ] **Step 5: Commit**

```bash
git add src/download-from-pokemon-db/cp.sh
git commit -m "Validate PokemonDB sprites before publishing, route rejects to review/"
```

---

### Task 3: Wire validation into the MBCMechachu copy script (small=68×68 / big=256×256)

**Files:**
- Modify: `src/cut-mbcmechachu-sprites/cp.sh`

**Interfaces:**
- Consumes: `src/validate_image/validate_image.sh <file> <expected_width> <expected_height>` from Task 1.

- [ ] **Step 1: Read the current script**

`src/cut-mbcmechachu-sprites/cp.sh` takes `$size` (`small` or `big`) and `$file` (`regular`/`shiny`) and copies into `images/$size/$file/$filename`:

```bash
for image in "$SCRIPT_DIR/temp/final/$size/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/$size/$file/$filename"

    countDifference=99999999999
    if test -f "$destinationFile"
    then
        countDifference=$(compare -metric AE "$image" "$destinationFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$destinationFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done
```

Only `small` is used today (`make mbc_copy`), but the script is generic over `$size`, so the expected dimensions must be resolved from `$size` rather than hardcoded.

- [ ] **Step 2: Add dimension resolution and validation to the loop**

Add this right after the `size=$1` / `file=$2` assignments near the top of the script:

```bash
case "$size" in
    small)
        expectedWidth=68
        expectedHeight=68
        ;;
    big)
        expectedWidth=256
        expectedHeight=256
        ;;
    *)
        echo "Unknown size '$size' (expected 'small' or 'big')" >&2
        exit 1
        ;;
esac
```

Then replace the loop body with:

```bash
for image in "$SCRIPT_DIR/temp/final/$size/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/$size/$file/$filename"

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" "$expectedWidth" "$expectedHeight"); then
        targetFile="$destinationFile"
    else
        targetFile="review/$size/$file/$filename"
        mkdir -p "$(dirname "$targetFile")"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    countDifference=99999999999
    if test -f "$targetFile"
    then
        countDifference=$(compare -metric AE "$image" "$targetFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$targetFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done
```

- [ ] **Step 3: Manually verify with a harmless fixture**

```bash
mkdir -p src/cut-mbcmechachu-sprites/temp/final/small/regular
convert -size 68x68 xc:blue src/cut-mbcmechachu-sprites/temp/final/small/regular/9999-test-valid.png
convert -size 30x30 xc:red src/cut-mbcmechachu-sprites/temp/final/small/regular/9999-test-invalid.png

bash src/cut-mbcmechachu-sprites/cp.sh small regular
```

Glob expansion is alphabetical, so `9999-test-invalid.png` is processed before `9999-test-valid.png`. The copy-if-changed step still runs after a reject (it just now targets `review/`), so expect both a `Reject` line and a `Copy` line for the invalid file:

```
Reject 9999-test-invalid.png: bad dimensions: 30x30 (expected 68x68)
Copy 9999-test-invalid.png
Copy 9999-test-valid.png
```

Verify placement:
```bash
ls images/small/regular/9999-test-valid.png        # exists
ls review/small/regular/9999-test-invalid.png       # exists
ls images/small/regular/9999-test-invalid.png       # does NOT exist
```

- [ ] **Step 4: Clean up the fixture**

```bash
rm -f images/small/regular/9999-test-valid.png
rm -f review/small/regular/9999-test-invalid.png
rmdir review/small/regular review/small 2>/dev/null || true
rm -rf src/cut-mbcmechachu-sprites/temp/final/small/regular
git status --short images/ review/
```

Expected: `git status --short images/ review/` prints nothing (clean).

- [ ] **Step 5: Commit**

```bash
git add src/cut-mbcmechachu-sprites/cp.sh
git commit -m "Validate MBCMechachu sprites before publishing, route rejects to review/"
```

---

### Task 4: Include `review/` changes in the automated PR

**Files:**
- Modify: `.github/workflows/update-images.yml`

- [ ] **Step 1: Read the current workflow step**

The final step of `.github/workflows/update-images.yml` currently has:

```yaml
      - name: Open a PR with any changed images
        uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "Update Pokémon images"
          branch: update-images-${{ github.run_id }}
          title: "Update Pokémon images"
          body-path: check_size_report.txt
          add-paths: images
          delete-branch: true
```

- [ ] **Step 2: Add `review` to `add-paths`**

Change `add-paths: images` to:

```yaml
          add-paths: |
            images
            review
```

So the full step reads:

```yaml
      - name: Open a PR with any changed images
        uses: peter-evans/create-pull-request@v7
        with:
          commit-message: "Update Pokémon images"
          branch: update-images-${{ github.run_id }}
          title: "Update Pokémon images"
          body-path: check_size_report.txt
          add-paths: |
            images
            review
          delete-branch: true
```

- [ ] **Step 3: Verify the YAML still parses**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/update-images.yml'))" && echo "YAML OK"
```

Expected: `YAML OK`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/update-images.yml
git commit -m "Include review/ changes in the automated image-update PR"
```

---

## Post-plan check

After Task 4, run `git status --short` at the repo root and confirm it's clean (no leftover fixture files under `images/` or `review/`) before considering the plan done.
