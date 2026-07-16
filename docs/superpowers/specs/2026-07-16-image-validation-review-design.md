# Image validation before publish — design

## Problem

`make pdb_copy` and `make mbc_copy` (invoked by the `update-images.yml` workflow)
copy newly downloaded/generated sprites straight into `images/big/...` and
`images/small/...`. The only quality check, `make check_size`, runs afterwards
and merely prints a report of bad-dimension files into the PR body — it never
stops a bad image from landing in `images/`, which is synced downstream to
`pokenini-resources` on every push to `main`.

We want invalid images to be routed to a separate, git-tracked directory for
human review instead of being published.

## Scope

In scope: the two automated copy scripts that write into `images/` —
`src/download-from-pokemon-db/cp.sh` (big/regular+shiny, always 256×256) and
`src/cut-mbcmechachu-sprites/cp.sh` (small/regular+shiny, always 68×68).

Out of scope:
- `images/banner` — hand-maintained from a `.xcf`/`.pxz` source, not part of
  the automated pipeline.
- `src/placeholders/make_them_all.sh` — currently writes to a `tmp/` scratch
  dir, not directly into `images/`, so there's nothing to gate.
- The existing `make check_size` Makefile target / workflow step — left as-is,
  a blanket final report over the whole `images/` tree. It becomes mostly
  redundant for pipeline-sourced images once validation runs at copy time, but
  still serves as a backstop for anything added outside the pipeline (e.g. a
  manually dropped banner image).

## Validity criteria

An image is valid when all of the following hold:
1. The file exists and is non-zero-size.
2. ImageMagick's `identify` can decode it (not truncated/corrupt).
3. The decoded format matches what the extension claims (a `.webp` file must
   actually decode as WEBP, a `.png` as PNG).
4. Its pixel dimensions exactly match the expected width/height for its
   category (256×256 for `big`, 68×68 for `small`).

## Design

### New shared script: `src/validate_image/validate_image.sh`

```
validate_image.sh <file> <expected_width> <expected_height>
```

- Exit 0, no output, if valid.
- Exit 1, one-line reason on stdout, if invalid (e.g. `empty file`,
  `unreadable/corrupt`, `format mismatch: expected PNG, got JPEG`,
  `bad dimensions: 64x64 (expected 68x68)`).

Implemented with `identify -format "%m %w %h" <file>` (already an
ImageMagick/`check_size.sh` dependency, so no new tooling is introduced).

### Wiring into the copy scripts

Both `cp.sh` scripts already loop over candidate images and, for each one,
decide whether to copy based on a diff (`compare -metric AE`) against the
existing file at the destination. That loop gains one step, run before the
diff check:

1. Call `validate_image.sh` with the expected dimensions for this script's
   category (`cp.sh` for big is always 256×256; `cp.sh` for small/big taking
   `$size` as today resolves 68×68 for `small`, 256×256 for `big`).
2. If valid → destination is unchanged: `images/<size>/<file>/<filename>`.
3. If invalid → destination becomes `review/<size>/<file>/<filename>`
   (same relative path, new root), created with `mkdir -p` since, unlike
   `images/`, the `review/` subtree doesn't pre-exist for every
   size/regular-shiny combination.
4. The existing "skip if identical to what's already at the destination"
   diff logic applies unchanged, just parameterized by whichever destination
   was chosen — so a review file that hasn't changed since the last run
   doesn't get re-copied/re-committed every time.
5. Reject reasons are printed (`printf`) alongside the existing
   `Copy %s` / `Done %d ...` messages, visible in the Action run log.

### `review/` directory

A new top-level directory, tracked in git (not gitignored), mirroring the
existing `images/{big,small}/{regular,shiny}` layout. Invalid images land
there as an ordinary file diff, so they show up in the auto-generated PR for
a human to inspect, fix upstream, or discard — nothing is silently dropped
and nothing invalid reaches `images/`.

### Workflow change

`.github/workflows/update-images.yml`: `add-paths: images` becomes

```yaml
add-paths: |
  images
  review
```

so changes under `review/` are included in the PR the workflow opens.

## Known limitation: no cross-root pruning

`images/` and `review/` are populated independently on each run; nothing
removes a stale entry from one root when the same image later lands
validly in the other. If a previously rejected image is fixed upstream,
the new run copies the corrected version into `images/`, but the old
rejected copy is left behind in `review/` — it isn't automatically
deleted. Conversely, if an image that was previously published later
starts failing validation, its last-good copy stays in `images/`
(intentional — publishing never gets silently rolled back) while the new
bad version also lands in `review/`. Cleaning up stale `review/` entries
is a manual step for whoever handles the review, not something the
pipeline does for you.

## Testing

No existing automated tests cover these bash scripts. Verification is
manual: run `pdb_copy`/`mbc_copy` against a small fixture set that includes
at least one deliberately bad image (wrong dimensions, corrupt/truncated
file, mislabeled extension) and confirm it lands under `review/` with a
sensible printed reason, while good images still land under `images/` as
before.
