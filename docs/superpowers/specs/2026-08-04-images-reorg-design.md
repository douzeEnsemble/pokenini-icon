# Images Directory Reorganization — Design

## Goal

Reorganize `pokenini-icon/images/` (and its mirror `review/`) from a flat
per-category layout into a two-level layout that groups by asset type first,
then by size/variant:

```
images/                          images/
  banner/                          banner/
    *.png, *.webp    (578x325)       large/*.png, *.webp   (578x325)
    thumb/*.png      (343x193)       thumbs/*.png          (343x193)
  big/{regular,shiny}               pokemon/
  small/{regular,shiny}               big/{regular,shiny}
review/                               small/{regular,shiny}
  big/{regular,shiny}              review/
                                      pokemon/
                                        big/{regular,shiny}
                                        small/{regular,shiny}
```

`images/index.html` is untouched (empty file, unaffected by the reorg).

This is a pure move: no image bytes change. The reorg also updates every
script, test, and downstream repo that hardcodes the old paths, since
`pokenini-icon` serves these directories directly as URL paths to
`pokenini-web`/`pokenini-back` (via a local Apache container and, in
production, via the synced `pokenini-resources` repo).

## Non-goals

- No change to image content, dimensions, or formats.
- No change to `pokenini-resources`' own code — its `make copy` target does
  a blind `cp -R ../pokenini-icon/images/* .`, so it inherits the new
  structure automatically the next time it's run. Re-syncing/deploying that
  repo is a deployment step outside this plan's scope.
- No change to `pokenini-api` — nothing there references these paths.
- No change to `src/banner/` (the GIMP source-art directory) — unrelated to
  `images/banner/`.

## pokenini-icon changes

### Directory moves (`git mv`, preserving history)

- `images/banner/*.png`, `images/banner/*.webp` → `images/banner/large/`
- `images/banner/thumb/` → `images/banner/thumbs/`
- `images/big/` → `images/pokemon/big/`
- `images/small/` → `images/pokemon/small/`
- `review/big/` → `review/pokemon/big/`

### Script/config updates

- **`Makefile`**: `banner_thumb` target's source/dest args become
  `images/banner/large images/banner/thumbs`. The four `check_size` target
  lines get the new paths (`images/banner/large`, `images/banner/thumbs`,
  `images/pokemon/big`, `images/pokemon/small`).
- **`src/check_size/check_size.sh`**: drop the
  `-not -path "$DIR/thumb/*"` exclusion. It existed because `thumb/` used to
  be nested inside the directory being checked (`images/banner`). After the
  reorg, `large/` and `thumbs/` are siblings under `images/banner/`, each
  checked independently by its own `check_size` invocation, so the
  exclusion no longer applies to anything and can be removed.
- **`src/convert_png_webp/convert_png_webp.sh`**: the `directories=(...)`
  array becomes `("images/banner/large" "images/pokemon/big/regular"
  "images/pokemon/big/shiny" "images/pokemon/small/regular"
  "images/pokemon/small/shiny")`. (Thumbnails stay PNG-only, as already
  decided in the banner-thumbnails design — not added to this array.)
- **`src/convert_png_webp/test_convert_png_webp.sh`**: update the fixture
  paths and expected-output strings to match (`images/banner/large/...`,
  `images/pokemon/big/...`, `images/pokemon/small/...`).
- **`src/download-from-pokemon-db/cp.sh`**: the hardcoded category argument
  to `copy_images.sh` changes from `big` to `pokemon/big`.
- **`src/koenig-sprites/cp.sh`**: the hardcoded category argument to
  `copy_images.sh` changes from `small` to `pokemon/small`.
- **`src/copy_images/copy_images.sh`**: no change. It already builds
  `images/$category/$file/$filename` and `review/$category/$file/$filename`
  generically from whatever `category` string it's given, and a category
  containing a `/` works fine with `mkdir -p`.
- **`src/copy_images/test_copy_images.sh`**: update fixture/expectation
  paths to include the `pokemon/` segment where they simulate the `small`
  category.
- **`src/placeholders/make_them_all.sh`**: `regularDirPath`/`shinyDirPath`
  gain a `pokemon/` segment (`images/pokemon/$dir/regular`,
  `images/pokemon/$dir/shiny`). The internal working dir
  (`src/placeholders/tmp/$dir/shiny`) is unaffected — it's scratch space,
  not part of the public layout.
- **`src/placeholders/test_make_them_all.sh`**: update fixture paths to
  match.
- **`README.md`**: update the one `images/small/` reference (in the Koenig
  sprites section) to `images/pokemon/small/`.

No changes needed to `.gitignore` or the two GitHub workflow files — neither
references these paths at a finer grain than `images` / `review`.

## Downstream repo changes

`pokenini-web` and `pokenini-back` both expose three Twig-consumed image URL
templates via env vars, using `sprintf`-style `%1$s`/`%2$s` placeholders that
are filled in with variant (`regular`/`shiny`) and slug:

| Env var | Old pattern (tail) | New pattern (tail) |
|---|---|---|
| `DEX_BANNER_URL` | `/banner/%1$s.png` | `/banner/large/%1$s.png` |
| `POKEMON_ICON_URL` | `/small/%1$s/%2$s.png` | `/pokemon/small/%1$s/%2$s.png` |
| `POKEMON_IMAGE_URL` | `/big/%1$s/%2$s.png` | `/pokemon/big/%1$s/%2$s.png` |

### pokenini-web

Update every `.env*` file that defines these three vars:
`.env`, `.env.dev`, `.env.dev.local`, `.env.test`, `.env.test.local`,
`.env.int`, `.env.prod`, `.env.ci`.

Update two integration tests with hardcoded URL-fragment assertions to
include the new `/pokemon` segment:
- `tests/src/Integration/Controller/Credits/CreditsTest.php` (4 assertions:
  `/small/regular/`, `/small/shiny/`, `/big/regular/`, `/big/shiny/`)
- `tests/src/Integration/Controller/Album/Display/CommonTest.php` (1
  assertion: `/small/regular/`)

No template or PHP code changes — templates consume the URL pattern as an
opaque configured string, so only the env-var values need to change.

### pokenini-back

Update the same three vars in the two files that define them:
`.env.dev.local`, `.env.prod`.

### pokenini-resources / pokenini-api

No code changes (see Non-goals).

## Testing / verification

- **pokenini-icon**: re-run each modified script's own test file
  (`test_convert_png_webp.sh`, `test_copy_images.sh`,
  `test_make_them_all.sh`) after updating paths — no test framework beyond
  these standalone bash scripts. Manually run `make check_size` and
  `make banner_thumb` against the real, moved `images/` tree to confirm the
  Makefile targets still work end-to-end (mirrors the verification step
  already used for the banner-thumbnails work).
- **pokenini-web**: run the two updated integration tests
  (`CreditsTest.php`, `CommonTest.php`) via the project's normal PHPUnit
  flow (`make test` or equivalent, inside that repo's own Docker toolchain)
  to confirm the new URL assertions pass against the updated env vars.
- **pokenini-back**: no automated test exercises these vars directly (per
  the earlier search, no code references them beyond config wiring for
  `pokenini-web`'s Twig globals) — a config-only sanity check
  (`grep` the updated `.env*` files) is sufficient.

## Risks

- **Deploy ordering**: production `pokenini-web`/`pokenini-back` point at
  `icon.pokenini.fr`, served by `pokenini-resources`. If the updated env
  vars in `pokenini-web`/`pokenini-back` reach production before
  `pokenini-resources` has re-synced from the reorganized `pokenini-icon`
  `images/`, image URLs will 404 until the sync catches up. This is a
  deployment sequencing concern, not something this plan can enforce
  automatically — flagged for the user to sequence manually.
- **Three independent git histories**: `pokenini-icon`, `pokenini-web`, and
  `pokenini-back` are separate repos with separate PRs/merges. The reorg
  isn't atomic across them; there will be a window where either the image
  paths or the consuming env vars are out of sync between repos on their
  respective `main` branches, same as the deploy-ordering risk above but at
  the repo level.
