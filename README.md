# Pokénini icons

## To Begin

### Webserver

#### Run

```
make install
```

#### Start

```
make start
```

#### Stop

```
make stop
```

### Scripts

#### Downloads sprites from PokemonDB

```
bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt rs 2> src/download-from-pokemon-db/errors.log
```

And see report_*.txt and errors.log files

To copy downloaded images to the final dir

```
bash src/download-from-pokemon-db/cp.sh big regular
bash src/download-from-pokemon-db/cp.sh big shiny
```

#### Koenig sprites

Downloads pre-cropped 68×68 icon sprites from
[koenigderluegner/pokemon-sprites](https://github.com/koenigderluegner/pokemon-sprites),
pinned to a specific commit in `src/koenig-sprites/SOURCE_SHA`.

##### Requirement

```
sudo apt-get update && sudo apt-get install jq
```

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
(currently 12 — see `select.sh`'s printed summary) are left untouched — their
existing art in `images/pokemon/small/` is preserved as-is. Note this only works for a
slug that already has art; a brand-new slug added to `pokenini-slugs.txt` with
no source match would get no image at all, not a placeholder. `select.sh` also
fails hard if matched coverage drops below 90% of `pokenini-slugs.txt`, to
catch a source rename/restructure early.

`pokenini-slugs.txt` is not auto-derived from `images/` — it must be updated
by hand whenever a new Pokémon/form slug is added to the project, otherwise
`select.sh` will never look for it.

To pick up upstream updates, bump `SOURCE_SHA` — either by hand, or by running
`bash src/koenig-sprites/update_sha.sh` (`make koenig_update_sha`), which resolves
the latest commit on the source repo's default branch via `git ls-remote` and
rewrites `SOURCE_SHA` if it changed. The `update-images` GitHub workflow runs
this automatically before every download, so upstream sprite changes flow into
the generated PR without a manual pin bump.

`download.sh` skips the download entirely if `src/koenig-sprites/temp/.downloaded_sha`
already matches `SOURCE_SHA` (and the extracted source is still present) — so
re-running the pipeline without bumping `SOURCE_SHA` is cheap. Deleting
`src/koenig-sprites/temp/` (or bumping `SOURCE_SHA`) forces a fresh download.

#### Placeholders sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install webp imagemagick
```

```
bash src/placeholders/make_them_all.sh s
bash src/placeholders/make_them_all.sh b
```

#### Banner generator

Composites banner PNGs from a base image plus named overlay layers. The
slug → layers mapping is no longer a committed file — it's fetched at
generation time from `pokenini-api`'s `GET /istration/dex-banner-layers`
endpoint (Basic auth, `icon` user), which reflects the "Banner Layers"
column of the Dex tab in the Google Sheet `pokenini-api` syncs from. This
replaces the old manual pixlr/GIMP export workflow described in
`src/banner/README.md` (still current for exporting individual named
layers, see `src/banner/export_layers.sh`) as well as the earlier
committed-`banners.json` approach.

```
bash src/banner_generate/generate.sh [destDir]
```

`destDir` defaults to `images/dex/banner`. Also runnable via `make banner_generate`, but note `BANNER_CONFIG_FILE` must point at a real config file you provide yourself — there is no committed default anymore (see below).

Overridable env vars:

- `BANNER_BASE_IMAGE` (default `src/banner_generate/base.png`) — the base canvas every banner starts from. **`base.png` is currently still a transparent placeholder, not real artwork** — nothing checks its content, so composing a brand-new slug (one that doesn't already have a PNG in `destDir`) before the real base image lands produces a placeholder-looking banner with no error, caught only by human PR review.
- `BANNER_LAYERS_DIR` (default `src/banner/layers`) — directory containing the named `<layer>.png` overlay files.
- `BANNER_CONFIG_FILE` (required, no default) — the slug -> layers config. In CI, this is fetched from `pokenini-api` and passed explicitly; for local use, provide a config file path.
- Per-layer blend mode / opacity: an optional `<layer>.json` file next to `<layer>.png` in `BANNER_LAYERS_DIR` (e.g. `shiny.json` next to `shiny.png`), see `src/banner/README.md`. A layer with no sidecar file composites with plain Over at 100%, same as before this option existed.
- `CONVERT_CONCURRENCY` (default `nproc`) — parallel `convert` workers.

The script hard-fails (non-zero exit, no files written) if the config file is
missing, isn't valid JSON, has a non-array value for any slug, or has any slug
mapped to an empty layer list `[]` — an empty list would otherwise silently
composite to "just the base image", producing a blank/placeholder-looking
banner instead of failing loudly. A slug whose output PNG already exists in
`destDir` is skipped (not regenerated) rather than erroring.

To force a banner to be regenerated, delete its `images/dex/banner/<slug>.png` first — the workflow only ever *adds* banners that don't exist yet.

The `update-banners` GitHub workflow fetches the config from `pokenini-api`,
runs `generate.sh`, then deletes each regenerated banner's stale `.webp` and
thumbnail before `make img_convert` / `make banner_thumb` run (those two
scripts skip files that already exist, so without this cleanup a
regenerated PNG's derived outputs would never refresh).

#### PNG to WEBP

Once all sources (PokemonDB, Koenig, placeholders) have been downloaded/copied,
convert every `.png` under `images/` to `.webp` in a single pass:

```
bash src/convert_png_webp/convert_png_webp.sh
```

#### Colour game sets

Fills the six colour columns of the Google Sheet `Pokémons` tab, used by the
colour game: `Regular colours codes`, `Shiny coulours codes`,
`Regular colours names`, `Shiny coulours names`, `Noms Couleurs normal` and
`Noms Couleurs chromatique`.

For each row, the script reads the `Small Regular Url` and `Small Shiny Url`
images, extracts their dominant colours (sprite outline excluded) and writes
5 sets per cell, separated by ` | ` (colours of a set separated by `;`). Set 1
is the right one, sets 2 to 5 are plausible decoys (other Pokémon palettes, or
the real palette with a hue shift). Sets are aligned across the codes, English
names and French names columns. The output is deterministic.

Only empty cells are filled: cells holding `-` and cells already filled are
kept (`--force` rewrites filled cells but still keeps `-`). Images are cached,
so the script can be run again without downloading everything.

##### Requirement

Python 3.12 or later.

```
pip install -r src/colours/requirements.txt
```

Export the `Pokémons` tab as CSV, then:

```
python3 src/colours/remplir_couleurs.py pokemons.csv -o pokemons_couleurs.csv --cache src/colours/cache
```

Also runnable via `make colours CSV=pokemons.csv`, which writes
`pokemons_couleurs.csv` next to the input. `--limit N` processes only the first
N rows to fill (trial run), `--offline` uses only cached images. See
`python3 src/colours/remplir_couleurs.py --help` for all options.

Import the output CSV back into the Sheet, then run the `pokenini-api`
Pokémons sync.
