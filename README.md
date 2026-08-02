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

To convert png to webp

```
bash src/download-from-pokemon-db/convert.sh regular
bash src/download-from-pokemon-db/convert.sh shiny
```

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
existing art in `images/small/` is preserved as-is. Note this only works for a
slug that already has art; a brand-new slug added to `pokenini-slugs.txt` with
no source match would get no image at all, not a placeholder. `select.sh` also
fails hard if matched coverage drops below 90% of `pokenini-slugs.txt`, to
catch a source rename/restructure early.

`pokenini-slugs.txt` is not auto-derived from `images/` — it must be updated
by hand whenever a new Pokémon/form slug is added to the project, otherwise
`select.sh` will never look for it.

To pick up upstream updates, bump `SOURCE_SHA` deliberately and re-run.

#### PNG to WEBP

Convert .png to .webp

```
bash src/convert_png_webp.sh
```

#### Placeholders sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install webp imagemagick
```

```
bash src/placeholders/make_them_all.sh s
bash src/placeholders/make_them_all.sh b
```
