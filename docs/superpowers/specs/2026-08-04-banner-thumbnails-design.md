# Generate resized banner thumbnails — design

## Problem

Banners in `images/banner/` are 578×325 PNGs (checked by `make check_size`).
A new use case needs a smaller variant — 343px wide, ratio preserved — but
nothing in the repo generates resized copies of an image; every existing
script in `src/` either copies, validates, or converts format (png→webp) at
the source resolution. We need a script that produces these thumbnails, only
for banners that don't already have one, following the conventions of the
sibling scripts under `src/`.

## Scope

In scope:
- New `src/banner_thumb/banner_thumb.sh` — generates width-resized PNG
  thumbnails from `images/banner/*.png` into `images/banner/thumb/`.
- New `src/banner_thumb/test_banner_thumb.sh` — direct test of the script.
- New Makefile target `banner_thumb`.

Out of scope:
- `.webp` generation for thumbnails — the user confirmed PNG-only for now;
  `img_convert` / `convert_png_webp.sh` already converts any `.png` under
  `images/` to `.webp`, so adding `images/banner/thumb` to its directory
  list (a one-line change in `convert_png_webp.sh`) is a natural follow-up
  but not part of this change.
- Resizing anything other than `images/banner/*.png` (e.g. `images/big`,
  `images/small`) — no stated need today.
- `check_size.sh` coverage of the new `thumb/` directory — its expected
  dimensions are derived (see below), not a fixed constant, so a
  width/height check doesn't apply the same way; not addressed here.

## Design

### `src/banner_thumb/banner_thumb.sh <sourceDir> <destDir> [width]`

Executable script, invoked directly (same sibling-path convention as
`copy_images.sh` calling `convert_webp.sh`), not sourced.

- `sourceDir` (required): directory to scan for `*.png`, non-recursive
  (e.g. `images/banner`).
- `destDir` (required): directory thumbnails are written to (e.g.
  `images/banner/thumb`). Created with `mkdir -p` if missing.
- `width` (optional): target width in pixels, default `343`.
- For each `$sourceDir/*.png`, if `$destDir/<filename>` does not already
  exist, generate it with:
  ```bash
  convert "$image" -resize "${width}x" "$destFile"
  ```
  The `<width>x` form (no height) is ImageMagick's standard "fit to this
  width, preserve aspect ratio" syntax — it computes and rounds the height
  itself, so the script never hardcodes or computes 578/325 anywhere. If
  `width` matches the source width, ImageMagick returns the image
  unchanged (no upscaling concern since 343 < 578).
- Already-present thumbnails are left untouched (skip-if-exists), same
  behavior as `convert_webp.sh`.
- Parallelized via `xargs -P "$CONVERT_CONCURRENCY"` (`: "${CONVERT_CONCURRENCY:=$(nproc)}"`),
  with `Start`/`Done <N> of <total>, in <T>s` output — mirrors
  `convert_webp.sh` exactly, since the two scripts do the same shape of
  work (conditionally transform each file in a directory, once).

### Makefile

```makefile
.PHONY        : banner_thumb
banner_thumb: ## Generate 343px-wide banner thumbnails
	bash src/banner_thumb/banner_thumb.sh images/banner images/banner/thumb
```

A dedicated target, run on demand — not chained into `img_convert` or
`check_size`, since thumbnail generation is a distinct step from
format-conversion and dimension-validation.

## Testing

`src/banner_thumb/test_banner_thumb.sh`, following the
`test_convert_webp.sh` style (real `convert` binary, no mocks, bash
assertion helpers):

- A 578×325 source PNG produces a `thumb/` PNG that is 343px wide with
  height preserving the source ratio (192 or 193px — assert against
  whatever ImageMagick actually produces, not a hand-computed value).
- A pre-existing `thumb/` file is left untouched (sentinel-content check,
  as in `test_convert_webp.sh` scenario 1).
- Empty source directory (nullglob) → `Done 0 of 0`, no error.
- Custom `width` argument produces a differently-sized thumbnail.
- `destDir` is created if it doesn't exist yet.
