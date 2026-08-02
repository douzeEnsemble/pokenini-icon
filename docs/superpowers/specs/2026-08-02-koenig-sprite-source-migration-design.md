# Small-sprite source migration (mbcmechachu → koenigderluegner/pokemon-sprites) — design

## Problem

The "small" (68×68) sprites are produced by `mbc_prepare` / `mbc_cut` / `mbc_copy`:
a Docker container running a Python + Wand (ImageMagick) script that crops
individual icons out of two committed spritesheets,
`src/cut-mbcmechachu-sprites/resources/{regulars,shinies}.png` (~4.2–4.3 MB
each), sourced from a single DeviantArt artwork by user **mbcmechachu**
("National Pokedex Icon Dex"). Crop geometry is hardcoded per-icon-size in
`config.ini`, and the spritesheet→slug mapping is a committed grid-position
CSV (`resources/pokemons-list.csv`).

This is fragile (a single static image, manually re-cropped whenever the
mapping needs a fix — see the "Need fixing" list in `README.md`) and heavy
(a whole Python/Wand/Docker toolchain just to cut 68×68 squares out of one
picture).

[koenigderluegner/pokemon-sprites](https://github.com/koenigderluegner/pokemon-sprites)
is a actively CI-regenerated collection of ~24k individual, pre-cropped
68×68 PNG icons (confirmed by direct download — `Bulbasaur.png` is exactly
68×68), shipped with a `data.json` metadata file. Its `slug` field already
matches pokenini's own icon-slug convention almost exactly (`venusaur-f`,
`venusaur-gmax`, …) — a direct comparison of the current 1600 pokenini
"small/regular" slugs against the source's 1711 base (no `n3ds`/`switch`
modifier, no `go`/`bonus`/`extra` category) slugs found **1520 exact
matches (95%)**. This design replaces the crop pipeline with a
download-and-select pipeline against that source.

## Scope

In scope: the "small" (68×68) image production path only —
`src/cut-mbcmechachu-sprites/` and the `mbc_*` Makefile targets /
workflow step. Everything downstream of `images/small/{regular,shiny}/`
(the shared `copy_images.sh` validation/review routing, `img_convert`,
`placeholders`, `check_size`) is reused unchanged.

Out of scope:
- The "big" (256×256) pipeline (`download-from-pokemon-db`, pokemondb.net)
  — untouched. `koenigderluegner/pokemon-sprites` doesn't offer an
  equivalent size/style, so there's nothing to replace it with here.
- Gender-variant sprites (`*-f` slugs) are **not** a new feature — pokenini
  already treats them as ordinary slugs today (e.g. `venusaur-f` is already
  a real file in `images/small/regular/`, driven by the `0003.00.00-♀`
  entry in the current `pokemons-list.csv`). This migration just changes
  where the pixels for those slugs come from, same as any other slug.
- Updating the per-Pokémon credit metadata (Google Sheet "Sprites url"
  column, and the in-progress credit-by-pokemon design in `pokenini-api`)
  to attribute "small" sprites to the new source instead of mbcmechachu.
  That's a data change in a different repo — flagged as a required
  follow-up, not part of this change.

## Design

### New source directory: `src/koenig-sprites/`

Mirrors the structure of `src/download-from-pokemon-db/` and
`src/cut-mbcmechachu-sprites/`: a self-contained folder with its own
scripts and resources, wired into the Makefile as its own set of targets.

### Pinning

`koenigderluegner/pokemon-sprites` has no tags or releases and
regenerates its sprites/data on every push to `main` via its own CI
(`update-icons-and-deploy.yml`). Tracking `main` directly would mean
sprites can silently change on every pokenini-icon run with no review
step — the opposite of how this pipeline currently works (mapping/source
changes are committed files, bumped deliberately).

A single committed file, `src/koenig-sprites/SOURCE_SHA`, holds the pinned
commit SHA (currently `71cd3c031c386dd418cc7b335490ae5ccbef6d0f`). Bumping
it to pick up upstream updates is a manual edit + PR, same spirit as
editing `pokemons-list.csv` today.

### `koenig_dl`: download

```
src/koenig-sprites/download.sh
```

- Reads the pinned SHA from `SOURCE_SHA`.
- Downloads `https://codeload.github.com/koenigderluegner/pokemon-sprites/tar.gz/<sha>`
  (confirmed ~48 MB at HEAD — comparable to what the current spritesheets +
  Docker image already cost) into `temp/source.tar.gz`.
- Extracts only `*/apps/pokemon-sprite/sprites/*.png` and
  `*/apps/pokemon-sprite/data.json` into `temp/source/`, discarding the
  rest of the tarball (docs, spritesheet.png, unrelated app code).

### `koenig_select`: build the mapping and stage matched files

```
src/koenig-sprites/select.sh
```

Uses `jq` (new dependency for this repo — replaces, not adds to, the
Python/Wand/Docker dependency the migration removes) to read
`temp/source/data.json` and build, for every `icons[]` entry with no
`modifiers`/`categories` on its `regular` side (i.e. the plain, non-3DS,
non-event base art):

- a `regular` source file → `<slug>` mapping, and
- if present, the paired `shiny` source file (same array entry,
  `modifiers: ["shiny"]`) → `<slug>` mapping.

For each pokenini target slug (read from a static committed list,
`src/koenig-sprites/resources/pokenini-slugs.txt`, generated once from the
current `images/small/regular/*` filenames and maintained like any other
resource file going forward):

1. Look up an exact `slug` match in the source mapping above.
2. If not found, look up `src/koenig-sprites/resources/aliases.csv`
   (`pokenini_slug,source_slug`) — a small, manually curated file seeded from the ~80 mismatches found
   during design (mostly notation differences, e.g. `charizard-mega-x` →
   `charizard-megax`).
3. If still not found, skip — the slug falls through to the existing
   `make placeholders` step, same as any currently-missing shiny does
   today. Known permanent gaps: `egg` (not a Pokémon) and the fan-made
   `*-mega-z` forms (`absol-mega-z`, `garchomp-mega-z`, `lucario-mega-z`,
   `mewtwo-mega-x`/`-y`) which don't exist in this source.

Matched files are copied (not moved) into
`temp/final/small/regular/<slug>.png` and `temp/final/small/shiny/<slug>.png`
— the exact directory layout `cp.sh` already expects, so step 3 needs no
new logic.

The script prints a one-line summary (`Matched %d/%d slugs (%d via alias,
%d unmatched)`) so a coverage regression after a future `SOURCE_SHA` bump
is visible in the Action log without needing to read the diff.

### `koenig_copy`: reuse the existing copy path

```
src/koenig-sprites/cp.sh
```

Identical in shape to today's `cut-mbcmechachu-sprites/cp.sh`: reads
`icon_width`/`icon_height` (68×68, moved into
`src/koenig-sprites/config.ini` since `cut-mbcmechachu-sprites/` is being
deleted) and calls the existing
`src/copy_images/copy_images.sh small "$dir" regular 68 68` /
`... shiny 68 68`. This is the script that already validates dimensions,
routes rejects to `review/`, and diffs against the current file before
copying — reused as-is, no changes needed to it.

### Makefile

```make
## —— Koenig sprites ————————————————————————————————————————————————————————
.PHONY        : koenig_dl koenig_select koenig_copy
koenig_dl: ## Download the pinned koenigderluegner/pokemon-sprites tarball
	bash src/koenig-sprites/download.sh
koenig_select: ## Select and stage sprites matching pokenini's slugs
	bash src/koenig-sprites/select.sh
koenig_copy: ## Copy staged images to the images/ folder
	bash src/koenig-sprites/cp.sh regular
	bash src/koenig-sprites/cp.sh shiny
```

`mbc_prepare` / `mbc_cut` / `mbc_copy` are deleted.

### Workflow (`update-images.yml`)

```yaml
      - name: Install image tooling
        run: sudo apt-get update && sudo apt-get install -y imagemagick webp jq

      - name: Download, convert and copy "big" sprites from pokemondb.net
        run: |
          make pdb_dl
          make pdb_convert
          make pdb_copy

      - name: Download and copy "small" sprites from koenigderluegner/pokemon-sprites
        run: |
          make koenig_dl
          make koenig_select
          make koenig_copy
```

(`jq` added to the tooling install step; the "Cut and copy small sprites"
step and its `mbc_prepare` Docker-build sub-step are gone — no Docker
build in this job anymore.)

### Cleanup

`src/cut-mbcmechachu-sprites/` (Python source, Dockerfile, pytest suite,
`config.ini`, the two committed spritesheets, `resources/pokemons-list.csv`)
is deleted in full once `koenig_*` is verified to reproduce equivalent
coverage. The README section "Cut MBCMechachu sprites" is replaced with a
"Koenig sprites" section describing `download.sh` / `select.sh` / `cp.sh`
the same way the PokemonDB section is documented today.

## Known limitations

- **Alias file is manual maintenance.** Every time `SOURCE_SHA` is bumped,
  a slug that previously matched by exact name could disappear if
  upstream renames it — it would silently fall through to `placeholders`
  rather than fail loudly. The `Matched %d/%d` summary line is the only
  guard; there's no hard failure threshold in this design (mirrors how
  `check_size` today is a report, not a gate).
- **No attribution automation.** `select.sh` doesn't touch credit
  metadata; the Google Sheet / `pokenini-api` credit system update is a
  separate, manual follow-up (see Scope).

## Testing

No existing automated tests cover the bash scripts in this pipeline
(same as the rest of `src/`). Verification is manual, same pattern as the
existing image-validation-review design:

1. Run `koenig_dl` / `koenig_select` / `koenig_copy` against the pinned
   SHA and confirm the `Matched %d/%d` summary is ~95%+ with the expected
   known gaps (`egg`, `*-mega-z` forms) accounting for the rest.
2. Spot-check a handful of copied files in `images/small/{regular,shiny}/`
   visually against the previous mbcmechachu-cropped versions for the same
   slugs (art style will differ — this is an expected, accepted
   consequence of switching source, not a bug).
3. Confirm `check_size` still reports 68×68 for everything under
   `images/small/`.
4. Confirm slugs with no source match land in `images/small/` via the
   existing `placeholders` step, not silently missing.
