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

Composites banner PNGs from a base image plus named overlay layers, driven by
`src/banner_generate/banners.json` (slug -> ordered list of layer names). This
replaces the old manual pixlr/GIMP export workflow described in
`src/banner/README.md`.

```
bash src/banner_generate/generate.sh [destDir]
```

`destDir` defaults to `images/dex/banner`. Also runnable via `make banner_generate`.

Overridable env vars:

- `BANNER_BASE_IMAGE` (default `src/banner_generate/base.png`) — the base canvas every banner starts from.
- `BANNER_LAYERS_DIR` (default `src/banner_generate/layers`) — directory containing the named `<layer>.png` overlay files.
- `BANNER_CONFIG_FILE` (default `src/banner_generate/banners.json`) — the slug -> layers config.
- `CONVERT_CONCURRENCY` (default `nproc`) — parallel `convert` workers.

The script hard-fails (non-zero exit, no files written) if the config file is
missing, isn't valid JSON, has a non-array value for any slug, or has any slug
mapped to an empty layer list `[]` — an empty list would otherwise silently
composite to "just the base image", producing a blank/placeholder-looking
banner instead of failing loudly.

**Placeholder status:** `src/banner_generate/base.png` is currently a fully
transparent placeholder, and every slug in `banners.json` is still seeded to
`[]` pending migration of the real layer artwork out of
`src/banner/pokenini_banner.pxz`/`.xcf`. Do **not** run this against
`images/dex/banner` until that migration lands — and per the empty-layer-list
guard above, the script will currently refuse to run against the checked-in
`banners.json` anyway.

The `update-banners` GitHub workflow runs `generate.sh`, then deletes each
regenerated banner's stale `.webp` and thumbnail before `make img_convert` /
`make banner_thumb` run (those two scripts skip files that already exist, so
without this cleanup a regenerated PNG's derived outputs would never refresh).

#### PNG to WEBP

Once all sources (PokemonDB, Koenig, placeholders) have been downloaded/copied,
convert every `.png` under `images/` to `.webp` in a single pass:

```
bash src/convert_png_webp/convert_png_webp.sh
```
