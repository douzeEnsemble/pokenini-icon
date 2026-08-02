# Small-Sprite Source Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mbcmechachu spritesheet-crop pipeline (Python/Wand/Docker, static committed spritesheets) with a download-and-select pipeline against `koenigderluegner/pokemon-sprites`, producing the same `images/small/{regular,shiny}/<slug>.png` output the rest of the pipeline already expects.

**Architecture:** A new `src/koenig-sprites/` directory, structured like the existing `src/download-from-pokemon-db/` and `src/cut-mbcmechachu-sprites/`: `download.sh` fetches a pinned-commit tarball and extracts the sprite PNGs + `data.json` metadata; `select.sh` uses `jq` to build a slug→filename manifest from `data.json` and stages matched files (direct slug match, or via a curated `aliases.csv`) into `temp/final/small/{regular,shiny}/<pokenini-slug>.png`; `cp.sh` reuses the existing, unmodified `src/copy_images/copy_images.sh` to publish into `images/small/...` (with its existing dimension-validation/`review/`-routing behavior). `mbc_*` Makefile targets and `src/cut-mbcmechachu-sprites/` are deleted once the new pipeline is verified.

**Tech Stack:** Bash, `jq`, `curl`, `tar` (all new-to-this-pipeline except curl; removes the Python/Wand/Docker dependency the old pipeline needed).

## Global Constraints

- Pinned source commit: `71cd3c031c386dd418cc7b335490ae5ccbef6d0f` (verified: tarball is 48 MB, contains 23805 sprite PNGs under `apps/pokemon-sprite/sprites/`, all confirmed 68×68, plus `apps/pokemon-sprite/data.json`, 7,662,611 bytes).
- Output must land in `temp/final/small/{regular,shiny}/<slug>.png` — the exact layout `src/copy_images/copy_images.sh` (unchanged, already handles size validation, `review/`-routing, and diff-before-copy) already expects.
- Coverage, verified end-to-end against the real pinned source and the real current 1600 pokenini "small/regular" slugs: **1588/1600 matched (68 via a curated alias table, 12 unmatched)**. The 12 unmatched fall through to the existing `make placeholders` step, same as any currently-missing shiny does today. They are permanent gaps (no equivalent art in the source): `egg`, `rockruff-owntempo`, `poltchageist-artisan`, `poltchageist-counterfeit`, `polteageist-antique`, `polteageist-phony`, `sinistea-antique`, `sinistea-phony`, `sinistcha-masterpiece`, `sinistcha-unremarkable`, `unown-em`, `unown-qm`.
- `jq` is a new tooling dependency, added alongside the existing `imagemagick`/`webp` install step in `update-images.yml`.
- Full design context: `docs/superpowers/specs/2026-08-02-koenig-sprite-source-migration-design.md`.
- No existing automated test framework covers the bash scripts in this pipeline (same situation as the rest of `src/`). Verification here is real runs against real fixtures/data, with expected output values taken from what was actually observed while designing this plan — not estimates.

---

### Task 1: Pin the source and write the download script

**Files:**
- Create: `src/koenig-sprites/SOURCE_SHA`
- Create: `src/koenig-sprites/download.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: running `bash src/koenig-sprites/download.sh` from the repo root populates `src/koenig-sprites/temp/koenig-source/` with every sprite PNG (flattened, original filenames like `Bulbasaur.png`, `Bulbasaur-★.png`) and `src/koenig-sprites/temp/koenig-source/data.json`. Depended on by Task 3.

- [ ] **Step 1: Write the pinned SHA file**

Create `src/koenig-sprites/SOURCE_SHA`:

```
71cd3c031c386dd418cc7b335490ae5ccbef6d0f
```

- [ ] **Step 2: Write the download script**

Create `src/koenig-sprites/download.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SHA=$(cat "$SCRIPT_DIR/SOURCE_SHA")
TEMP_DIR="$SCRIPT_DIR/temp"
ARCHIVE="$TEMP_DIR/koenig-source.tar.gz"
SOURCE_DIR="$TEMP_DIR/koenig-source"

rm -rf "$SOURCE_DIR"
mkdir -p "$SOURCE_DIR"

printf "Downloading koenigderluegner/pokemon-sprites @ %s\n" "$SHA"
curl -fsSL -o "$ARCHIVE" "https://codeload.github.com/koenigderluegner/pokemon-sprites/tar.gz/$SHA"

tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --wildcards --strip-components=4 "*/apps/pokemon-sprite/sprites/*.png"
tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --wildcards --strip-components=3 "*/apps/pokemon-sprite/data.json"

count=$(find "$SOURCE_DIR" -maxdepth 1 -name '*.png' | wc -l)
printf "Extracted %d sprite PNGs and data.json into %s\n" "$count" "$SOURCE_DIR"
```

```bash
chmod +x src/koenig-sprites/download.sh
```

- [ ] **Step 3: Add the scratch directory to `.gitignore`**

Add this block to `.gitignore` (matching the existing `src/cut-mbcmechachu-sprites/temp/*` entry style):

```
src/koenig-sprites/temp/*
```

- [ ] **Step 4: Run it for real and verify the counts**

Run: `bash src/koenig-sprites/download.sh`

Expected output:
```
Downloading koenigderluegner/pokemon-sprites @ 71cd3c031c386dd418cc7b335490ae5ccbef6d0f
Extracted 23805 sprite PNGs and data.json into .../src/koenig-sprites/temp/koenig-source
```

Then:
```bash
ls src/koenig-sprites/temp/koenig-source/data.json   # exists
identify -format "%wx%h" src/koenig-sprites/temp/koenig-source/Bulbasaur.png   # 68x68
```

- [ ] **Step 5: Commit**

```bash
git add src/koenig-sprites/SOURCE_SHA src/koenig-sprites/download.sh .gitignore
git commit -m "Add koenigderluegner/pokemon-sprites download script"
```

---

### Task 2: Generate the pokenini slug list and the alias table

**Files:**
- Create: `src/koenig-sprites/resources/pokenini-slugs.txt`
- Create: `src/koenig-sprites/resources/aliases.csv`

**Interfaces:**
- Produces: `src/koenig-sprites/resources/pokenini-slugs.txt` (one pokenini icon slug per line, 1600 lines) and `src/koenig-sprites/resources/aliases.csv` (`pokenini_slug,source_slug`, 68 lines) — both consumed by Task 3's `select.sh`.

- [ ] **Step 1: Generate the current slug list from `images/`**

```bash
mkdir -p src/koenig-sprites/resources
find images/small/regular -type f | sed -E 's#.*/##; s#\.(webp|png)$##' | sort -u > src/koenig-sprites/resources/pokenini-slugs.txt
wc -l src/koenig-sprites/resources/pokenini-slugs.txt
```

Expected: `1600 src/koenig-sprites/resources/pokenini-slugs.txt`.

- [ ] **Step 2: Write the alias table**

These 68 mappings were resolved by inspecting `data.json` for each pokenini slug that had no exact `slug` match in the source (grouped by pattern: fan-content "Mega Z"/"Mega X/Y" notation, Arceus plate items, Silvally memory items, Castform weather names, Genesect drive names, Maushold family-size names, Necrozma wing/mane names, Ogerpon mask names, and a handful of one-off naming differences). Every row below was verified against the pinned source's `data.json`: the `source_slug` exists with both a regular and shiny icon.

Create `src/koenig-sprites/resources/aliases.csv`:

```csv
absol-mega-z,absol-megaz
charizard-mega-x,charizard-megax
charizard-mega-y,charizard-megay
garchomp-mega-z,garchomp-megaz
lucario-mega-z,lucario-megaz
mewtwo-mega-x,mewtwo-megax
mewtwo-mega-y,mewtwo-megay
pichu-spiky-eared,pichu-spikyeared
raichu-mega-x,raichu-megax
raichu-mega-y,raichu-megay
arceus-bug,arceus-insectplate
arceus-dark,arceus-dreadplate
arceus-dragon,arceus-dracoplate
arceus-electric,arceus-zapplate
arceus-fairy,arceus-pixieplate
arceus-fighting,arceus-fistplate
arceus-fire,arceus-flameplate
arceus-flying,arceus-skyplate
arceus-ghost,arceus-spookyplate
arceus-grass,arceus-meadowplate
arceus-ground,arceus-earthplate
arceus-ice,arceus-icicleplate
arceus-poison,arceus-toxicplate
arceus-psychic,arceus-mindplate
arceus-rock,arceus-stoneplate
arceus-steel,arceus-ironplate
arceus-water,arceus-splashplate
silvally-bug,silvally-bug-memory
silvally-dark,silvally-dark-memory
silvally-dragon,silvally-dragon-memory
silvally-electric,silvally-electric-memory
silvally-fairy,silvally-fairy-memory
silvally-fighting,silvally-fighting-memory
silvally-fire,silvally-fire-memory
silvally-flying,silvally-flying-memory
silvally-ghost,silvally-ghost-memory
silvally-grass,silvally-grass-memory
silvally-ground,silvally-ground-memory
silvally-ice,silvally-ice-memory
silvally-poison,silvally-poison-memory
silvally-psychic,silvally-psychic-memory
silvally-rock,silvally-rock-memory
silvally-steel,silvally-steel-memory
silvally-water,silvally-water-memory
castform-rainy,castform-rain
castform-snowy,castform-snow
castform-sunny,castform-sun
genesect-burn-drive,genesect-burn
genesect-chill-drive,genesect-chill
genesect-douse-drive,genesect-douse
genesect-shock-drive,genesect-shock
maushold-four,maushold-family-of-four
maushold-three,maushold-family-of-three
necrozma-dawn,necrozma-dawn-wings
necrozma-dusk,necrozma-dusk-mane
ogerpon-cornerstone-mask,ogerpon-cornerstone
ogerpon-hearthflame-mask,ogerpon-hearthflame
ogerpon-teal-mask,ogerpon-teal
ogerpon-wellspring-mask,ogerpon-wellspring
oricorio-baile,oricorio-baille
pikachu-belle,pikachu-cosplay-belle
pikachu-libre,pikachu-cosplay-libre
pikachu-phd,pikachu-cosplay-ph-d
pikachu-pop-star,pikachu-cosplay-popstar
pikachu-rock-star,pikachu-cosplay-rockstar
tauros-paldea-fire,tauros-paldea-blaze
tauros-paldea-water,tauros-paldea-aqua
vivillon-icy-snow,vivillon-icy-wind
```

- [ ] **Step 3: Verify coverage against the real downloaded source (requires Task 1 done)**

```bash
jq -r '
  .[] | .icons[] |
  select(.regular != null and (.regular.modifiers // []) == [] and (.regular.categories // []) == []) |
  ([.regular.slug, "regular"] | @tsv),
  (if .shiny != null and (.shiny.modifiers // []) == ["shiny"] then
      ([.regular.slug, "shiny"] | @tsv)
   else empty end)
' src/koenig-sprites/temp/koenig-source/data.json | awk -F'\t' '$2=="regular"{print $1}' | sort -u > /tmp/source-base-slugs.txt

comm -23 <(sort -u src/koenig-sprites/resources/pokenini-slugs.txt) /tmp/source-base-slugs.txt | while read -r slug; do
    grep -q "^$slug," src/koenig-sprites/resources/aliases.csv && continue
    echo "$slug"
done | sort > /tmp/still-unmatched.txt

wc -l /tmp/still-unmatched.txt
cat /tmp/still-unmatched.txt
```

Expected: `12 /tmp/still-unmatched.txt`, listing exactly:
```
egg
poltchageist-artisan
poltchageist-counterfeit
polteageist-antique
polteageist-phony
rockruff-owntempo
sinistcha-masterpiece
sinistcha-unremarkable
sinistea-antique
sinistea-phony
unown-em
unown-qm
```

These 12 are expected (see Global Constraints) — they'll fall through to `make placeholders` in Task 5's wiring, same as today's missing-shiny handling.

- [ ] **Step 4: Commit**

```bash
git add src/koenig-sprites/resources/pokenini-slugs.txt src/koenig-sprites/resources/aliases.csv
git commit -m "Add pokenini slug list and koenig-sprites alias table"
```

---

### Task 3: Write `select.sh` — match and stage sprites

**Files:**
- Create: `src/koenig-sprites/select.sh`

**Interfaces:**
- Consumes: `src/koenig-sprites/temp/koenig-source/{*.png,data.json}` from Task 1; `src/koenig-sprites/resources/{pokenini-slugs.txt,aliases.csv}` from Task 2.
- Produces: `src/koenig-sprites/temp/final/small/{regular,shiny}/<slug>.png` — consumed by Task 4's `cp.sh`.

- [ ] **Step 1: Write the script**

Create `src/koenig-sprites/select.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SOURCE_DIR="$SCRIPT_DIR/temp/koenig-source"
STAGE_DIR="$SCRIPT_DIR/temp/final/small"
MANIFEST="$SCRIPT_DIR/temp/manifest.tsv"
ALIASES="$SCRIPT_DIR/resources/aliases.csv"
SLUGS="$SCRIPT_DIR/resources/pokenini-slugs.txt"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/regular" "$STAGE_DIR/shiny"

jq -r '
  .[] | .icons[] |
  select(.regular != null and (.regular.modifiers // []) == [] and (.regular.categories // []) == []) |
  (
    ([.regular.slug, "regular", (.regular.name + ".png")] | @tsv),
    (if .shiny != null and (.shiny.modifiers // []) == ["shiny"] then
        ([.regular.slug, "shiny", (.shiny.name + ".png")] | @tsv)
     else empty end)
  )
' "$SOURCE_DIR/data.json" > "$MANIFEST"

matched=0
aliased=0
missing=0
missingList=()

while IFS= read -r pokeniniSlug; do
    [ -z "$pokeniniSlug" ] && continue

    sourceSlug="$pokeniniSlug"
    viaAlias=0
    aliasTarget=$(awk -F, -v s="$pokeniniSlug" '$1==s{print $2; exit}' "$ALIASES")
    if [ -n "$aliasTarget" ]; then
        sourceSlug="$aliasTarget"
        viaAlias=1
    fi

    regularFile=$(awk -F'\t' -v s="$sourceSlug" '$1==s && $2=="regular"{print $3; exit}' "$MANIFEST")
    shinyFile=$(awk -F'\t' -v s="$sourceSlug" '$1==s && $2=="shiny"{print $3; exit}' "$MANIFEST")

    if [ -z "$regularFile" ]; then
        missing=$((missing+1))
        missingList+=("$pokeniniSlug")
        continue
    fi

    cp "$SOURCE_DIR/$regularFile" "$STAGE_DIR/regular/$pokeniniSlug.png"
    if [ -n "$shinyFile" ]; then
        cp "$SOURCE_DIR/$shinyFile" "$STAGE_DIR/shiny/$pokeniniSlug.png"
    fi

    matched=$((matched+1))
    [ "$viaAlias" -eq 1 ] && aliased=$((aliased+1))
done < "$SLUGS"

total=$((matched+missing))
printf "Matched %d/%d slugs (%d via alias, %d unmatched)\n" "$matched" "$total" "$aliased" "$missing"
if [ "$missing" -gt 0 ]; then
    printf "Unmatched (falls through to placeholders): %s\n" "${missingList[*]}"
fi
```

```bash
chmod +x src/koenig-sprites/select.sh
```

- [ ] **Step 2: Run it and verify the summary**

Run: `bash src/koenig-sprites/select.sh`

Expected:
```
Matched 1588/1600 slugs (68 via alias, 12 unmatched)
Unmatched (falls through to placeholders): egg poltchageist-artisan poltchageist-counterfeit polteageist-antique polteageist-phony rockruff-owntempo sinistcha-masterpiece sinistcha-unremarkable sinistea-antique sinistea-phony unown-em unown-qm
```

- [ ] **Step 3: Verify staged file counts and dimensions**

```bash
find src/koenig-sprites/temp/final/small/regular -name '*.png' | wc -l   # 1588
find src/koenig-sprites/temp/final/small/shiny -name '*.png' | wc -l    # 1587 (egg-manaphy has no shiny in the source — falls through to placeholders for that one slot only, same as any other missing shiny today)
identify -format "%wx%h" src/koenig-sprites/temp/final/small/regular/venusaur-f.png   # 68x68
identify -format "%wx%h" src/koenig-sprites/temp/final/small/regular/arceus-bug.png   # 68x68 (via alias arceus-insectplate)
```

- [ ] **Step 4: Commit**

```bash
git add src/koenig-sprites/select.sh
git commit -m "Add koenig-sprites select.sh: match and stage sprites by slug"
```

---

### Task 4: `config.ini` and `cp.sh` — publish staged sprites into `images/`

**Files:**
- Create: `src/koenig-sprites/config.ini`
- Create: `src/koenig-sprites/cp.sh`

**Interfaces:**
- Consumes: `src/copy_images/copy_images.sh <category> <sourceDir> <file> <expectedWidth> <expectedHeight>` (existing, unmodified script — see `src/cut-mbcmechachu-sprites/cp.sh` for the reference usage pattern).
- Produces: `bash src/koenig-sprites/cp.sh regular` / `bash src/koenig-sprites/cp.sh shiny`, consumed by the Makefile in Task 5.

- [ ] **Step 1: Write `config.ini`**

Create `src/koenig-sprites/config.ini`:

```ini
[Sprite]
icon_width = 68
icon_height = 68
```

- [ ] **Step 2: Write `cp.sh`**

Create `src/koenig-sprites/cp.sh` (mirrors `src/cut-mbcmechachu-sprites/cp.sh`):

```bash
#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

expectedWidth=$(awk -F ' *= *' '/^icon_width/{print $2; exit}' "$SCRIPT_DIR/config.ini")
expectedHeight=$(awk -F ' *= *' '/^icon_height/{print $2; exit}' "$SCRIPT_DIR/config.ini")

"$SCRIPT_DIR/../copy_images/copy_images.sh" small "$SCRIPT_DIR/temp/final/small/$file" "$file" "$expectedWidth" "$expectedHeight"
```

```bash
chmod +x src/koenig-sprites/cp.sh
```

- [ ] **Step 3: Verify with a harmless fixture (does not touch real pokemon data)**

Same pattern as the existing image-validation-review plan: use a fake slug (`9999-test`) so nothing collides with real sprites.

```bash
mkdir -p src/koenig-sprites/temp/final/small/regular
convert -size 68x68 xc:blue src/koenig-sprites/temp/final/small/regular/9999-test-valid.png
convert -size 30x30 xc:red src/koenig-sprites/temp/final/small/regular/9999-test-invalid.png

bash src/koenig-sprites/cp.sh regular
```

Glob expansion is alphabetical, so `9999-test-invalid.png` is processed before `9999-test-valid.png`. Expect:
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
rm -rf src/koenig-sprites/temp/final/small/regular
git status --short images/ review/
```

Expected: `git status --short images/ review/` prints nothing (clean).

- [ ] **Step 5: Commit**

```bash
git add src/koenig-sprites/config.ini src/koenig-sprites/cp.sh
git commit -m "Add koenig-sprites config.ini and cp.sh"
```

---

### Task 5: Wire into the Makefile and workflow

**Files:**
- Modify: `Makefile`
- Modify: `.github/workflows/update-images.yml`

**Interfaces:**
- Consumes: `download.sh` (Task 1), `select.sh` (Task 3), `cp.sh` (Task 4).

- [ ] **Step 1: Replace the `mbc_*` Makefile targets**

In `Makefile`, remove:

```make
## —— MBCMechachu ————————————————————————————————————————————————————————————————
.PHONY        : mbc_prepare mbc_cut mbc_copy
mbc_prepare: ## Prepare the Docker image
	docker build -f src/cut-mbcmechachu-sprites/Dockerfile src/cut-mbcmechachu-sprites --rm -t cut-mbcmechachu-sprites
mbc_cut: ## Cut the sprites into individual images
	docker run -i --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py regular complete
	docker run -i --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py shiny complete
mbc_copy: ## Copy images to the images/ folder
	bash src/cut-mbcmechachu-sprites/cp.sh regular
	bash src/cut-mbcmechachu-sprites/cp.sh shiny
```

Replace with:

```make
## —— Koenig sprites ————————————————————————————————————————————————————————————
.PHONY        : koenig_dl koenig_select koenig_copy
koenig_dl: ## Download the pinned koenigderluegner/pokemon-sprites tarball
	bash src/koenig-sprites/download.sh
koenig_select: ## Select and stage sprites matching pokenini's slugs
	bash src/koenig-sprites/select.sh
koenig_copy: ## Copy staged images to the images/ folder
	bash src/koenig-sprites/cp.sh regular
	bash src/koenig-sprites/cp.sh shiny
```

- [ ] **Step 2: Verify the Makefile still parses**

Run: `make help | grep -i koenig`

Expected:
```
koenig_dl                     Download the pinned koenigderluegner/pokemon-sprites tarball
koenig_select                 Select and stage sprites matching pokenini's slugs
koenig_copy                   Copy staged images to the images/ folder
```

(And `make help | grep -i mbc` now prints nothing.)

- [ ] **Step 3: Update the workflow**

In `.github/workflows/update-images.yml`, change:

```yaml
      - name: Install image tooling
        run: sudo apt-get update && sudo apt-get install -y imagemagick webp
```

to:

```yaml
      - name: Install image tooling
        run: sudo apt-get update && sudo apt-get install -y imagemagick webp jq
```

And replace:

```yaml
      - name: Cut and copy "small" sprites from the static spritesheet
        run: |
          make mbc_prepare
          make mbc_cut
          make mbc_copy
```

with:

```yaml
      - name: Download and copy "small" sprites from koenigderluegner/pokemon-sprites
        run: |
          make koenig_dl
          make koenig_select
          make koenig_copy
```

- [ ] **Step 4: Verify the YAML still parses**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/update-images.yml'))" && echo "YAML OK"
```

Expected: `YAML OK`.

- [ ] **Step 5: Commit**

```bash
git add Makefile .github/workflows/update-images.yml
git commit -m "Wire koenig-sprites into the Makefile and update-images workflow"
```

---

### Task 6: Remove the old mbcmechachu pipeline and update docs

**Files:**
- Delete: `src/cut-mbcmechachu-sprites/`
- Modify: `.gitignore`
- Modify: `README.md`

- [ ] **Step 1: Delete the old pipeline directory**

```bash
git rm -r src/cut-mbcmechachu-sprites
```

- [ ] **Step 2: Remove its `.gitignore` entries**

Remove these lines from `.gitignore`:

```
src/cut-mbcmechachu-sprites/images/*
src/cut-mbcmechachu-sprites/report_*.txt
src/cut-mbcmechachu-sprites/errors.log
src/cut-mbcmechachu-sprites/output.txt

src/cut-mbcmechachu-sprites/temp/*
```

- [ ] **Step 3: Replace the README section**

In `README.md`, remove the entire "Cut MBCMechachu sprites" section (from `#### Cut MBCMechachu sprites` through the `bash src/cut-mbcmechachu-sprites/cp.sh regular` / `shiny` lines and its "Testing" subsection), and replace it with:

```markdown
#### Koenig sprites

Downloads pre-cropped 68×68 icon sprites from
[koenigderluegner/pokemon-sprites](https://github.com/koenigderluegner/pokemon-sprites),
pinned to a specific commit in `src/koenig-sprites/SOURCE_SHA`.

```
bash src/koenig-sprites/download.sh
bash src/koenig-sprites/select.sh
bash src/koenig-sprites/cp.sh regular
bash src/koenig-sprites/cp.sh shiny
```

`select.sh` matches pokenini's icon slugs (`src/koenig-sprites/resources/pokenini-slugs.txt`)
against the source's `data.json`, directly or via
`src/koenig-sprites/resources/aliases.csv` for the ~70 slugs where naming differs
(e.g. `arceus-bug` → `arceus-insectplate`). Slugs with no match in the source
(currently 12 — see `select.sh`'s printed summary) fall through to
`make placeholders`, same as any missing shiny does today. To pick up
upstream updates, bump `SOURCE_SHA` deliberately and re-run.
```

- [ ] **Step 4: Verify nothing references the deleted directory**

```bash
grep -rn "cut-mbcmechachu-sprites\|mbc_prepare\|mbc_cut\|mbc_copy" --include="*.yml" --include="Makefile" --include="*.md" . 2>/dev/null
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Remove the mbcmechachu crop pipeline, superseded by koenig-sprites"
```

---

## Post-plan check

After Task 6, run `git status --short` at the repo root and confirm it's clean (no leftover fixture or `temp/` files tracked) before considering the plan done.

**Not covered by this plan (deliberately):** actually running the new pipeline against production `images/` (via `workflow_dispatch` on `update-images.yml`) to swap ~1588 real sprites and open the resulting PR. That's an operational step the workflow already handles — same as any other `update-images` run — and touches thousands of files served to real users, so it's left as a separate, explicit trigger rather than bundled into this implementation plan.
