# Factor out the shared cwebp-conversion logic — design

## Problem

`src/download-from-pokemon-db/convert.sh` and `src/convert_png_webp/convert_png_webp.sh`
both contain a near-identical `convert_one` function (parallel `cwebp -q 100
-z 9 -m 6` conversion via `xargs -P`, introduced by
[2026-08-02-pokemondb-download-parallelization](2026-08-02-pokemondb-download-parallelization-design.md)).
The two scripts differ only in how they iterate directories: `convert.sh`
converts one `$SCRIPT_DIR`-prefixed directory per invocation, while
`convert_png_webp.sh` loops over five cwd-relative directories. This
duplication was previously flagged during code review and deliberately
left in place (human ruling: matches the codebase's convention of small,
independent scripts). This design revisits that ruling at the user's
request and factors the shared logic out.

`src/download-from-pokemon-db/cp.sh` and `src/koenig-sprites/cp.sh` were
also raised as candidates, but on inspection both are already thin
(5-10 line) wrappers that delegate to the already-shared
`src/copy_images/copy_images.sh` — there is no duplicated logic block to
extract. They are explicitly out of scope; touching them would be
diff-for-diff's-sake with no reduction in duplication.

## Scope

In scope:
- New `src/convert_webp/convert_webp.sh` — the single shared implementation.
- `src/download-from-pokemon-db/convert.sh` — reduced to a one-line delegating wrapper.
- `src/convert_png_webp/convert_png_webp.sh` — its directory loop now delegates per-directory instead of inlining the conversion.
- New `src/convert_webp/test_convert_webp.sh` — direct test of the shared script.
- `src/convert_png_webp/test_convert_png_webp.sh` — two assertions updated for the new output format (see below).

Out of scope:
- `src/download-from-pokemon-db/cp.sh`, `src/koenig-sprites/cp.sh` — already sufficiently factored (see Problem).
- `cwebp` flags, concurrency default (`$(nproc)`), or any behavior change beyond the output-format unification described below.
- `src/download-from-pokemon-db/test_convert.sh` — no changes; its assertions describe wrapper behavior that stays identical.

## Design

### `src/convert_webp/convert_webp.sh <directory> [label]`

The single shared implementation, executable, invoked by direct path
(`"$SCRIPT_DIR/../convert_webp/convert_webp.sh" ...`) — the same
call-by-sibling-path convention already used for
`copy_images.sh`/`validate_image.sh`, not a sourced library. This keeps
every script directory self-contained and independently invocable, matching
the existing repo structure.

- `directory` (required): path to scan for `*.png`, non-recursive. Resolved
  exactly as given — absolute if the caller passes absolute (as
  `convert.sh` will), relative to the caller's cwd if relative (as
  `convert_png_webp.sh` will, matching its current behavior of reading
  `images/banner` etc. relative to the repo root the Makefile invokes it
  from). `convert_webp.sh` does no path resolution of its own.
- `label` (optional): text used in the `Start`/`Done` messages. Defaults to
  `directory` when omitted (this is what `convert_png_webp.sh` will rely
  on — its dir path IS the label it already prints today). `convert.sh`
  passes its own `$file` ("regular"/"shiny") explicitly, to keep its output
  text byte-identical to today.
- `CONVERT_CONCURRENCY` env var, default `$(nproc)`, same `: "${VAR:=default}"` convention as today.
- Output: `"Start <label>"` then `"Done <N> of <total> <label>, in <T>s"`.

This is the `convert.sh` format applied uniformly. Today
`convert_png_webp.sh` prints `"Done <N> <label>, in <T>s"` (no total count)
— this changes to include the total, a small but strictly more informative
output change. Nothing outside the test files parses this text (checked:
grepped the Makefile and both GitHub workflow files for anything matching
the output format — only the two test files and this Makefile's `bash
.../script.sh` invocations reference these scripts at all), so the format
is free to unify.

### Callers become one-line-of-logic wrappers

```bash
# src/download-from-pokemon-db/convert.sh
"$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$SCRIPT_DIR/images/temp/$file" "$file"
```

```bash
# src/convert_png_webp/convert_png_webp.sh — loop stays, body is now one delegating line
for dir in "${directories[@]}"; do
    "$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$dir"
done
```

Both callers drop their own `convert_one`/`DONE_FILE`/`trap` entirely —
that bookkeeping now lives once, in `convert_webp.sh`.

## Testing

- New `src/convert_webp/test_convert_webp.sh`, following the existing
  `test_copy_images.sh`/`test_convert.sh` style (real `cwebp`/`convert`
  binaries, no mocks): covers skip-if-exists, empty-directory (nullglob),
  default label (= directory) vs. explicit label override, and the `of
  <total>` count.
- `src/download-from-pokemon-db/test_convert.sh`: no changes. It asserts on
  `convert.sh`'s output text, which stays identical because the label is
  passed through explicitly.
- `src/convert_png_webp/test_convert_png_webp.sh`: two regex assertions
  gain `of N`:
  `'Done 1 images/banner, in [0-9]+s'` → `'Done 1 of 1 images/banner, in [0-9]+s'`,
  `'Done 0 images/small/regular, in [0-9]+s'` → `'Done 0 of 0 images/small/regular, in [0-9]+s'`.
