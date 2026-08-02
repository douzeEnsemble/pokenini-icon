# Parallelize pokemondb download/convert/copy pipeline — design

## Problem

`src/download-from-pokemon-db/` produces the "big" (256×256) sprites through
three sequential Bash scripts:

- `download-from-pokemondb.sh` — reads `pokemons-list.txt` (1677 lines) and,
  for each line, `wget`s regular and shiny sprites from img.pokemondb.net
  **one HTTP request at a time**, up to 3354 sequential requests.
- `convert.sh` — walks `images/temp/{regular,shiny}/*.png` and runs `cwebp`
  on each file **one at a time** (CPU-bound, near-max-effort settings
  `-q 100 -z 9 -m 6`).
- `cp.sh` (→ `copy_images/copy_images.sh`) — for each image, runs
  `validate_image.sh` (spawns `identify`) and ImageMagick `compare` against
  the existing committed file, **one at a time**.

None of these loops have any cross-iteration dependency — they're
embarrassingly parallel — but none of them parallelize today, so wall-clock
time is dominated by per-request/per-process latency rather than actual
network or CPU throughput. `src/convert_png_webp/convert_png_webp.sh` (used
in CI to regenerate "small" webp sprites) has the identical sequential
`cwebp`-per-file pattern.

Separately, in CI (`.github/workflows/update-images.yml`),
`src/download-from-pokemon-db/images/*` is gitignored (`.gitignore:1`), so
every `workflow_dispatch` run starts with an empty `images/temp/` — the
scripts' own "skip if file already exists" checks never get a chance to
skip anything, and the workflow re-downloads and re-converts all ~3354
sprites from scratch every time it runs, even if `pokemons-list.txt` hasn't
changed since the last run.

## Scope

In scope:
- `download-from-pokemon-db/download-from-pokemondb.sh`
- `download-from-pokemon-db/convert.sh`
- `copy_images/copy_images.sh` (invoked via `download-from-pokemon-db/cp.sh`)
- `convert_png_webp/convert_png_webp.sh` (same pattern, used by CI's
  "Regenerate small webp sprites" step)
- `.github/workflows/update-images.yml` — add a cache step for
  `src/download-from-pokemon-db/images/temp/`

Out of scope:
- `src/koenig-sprites/` pipeline (already a single bulk tarball download,
  not a per-file loop — nothing to parallelize).
- Changing `cwebp` quality/effort settings (`-q 100 -z 9 -m 6`) to trade
  quality for speed — not requested, and changes output bytes.
- `check_size.sh` / `placeholders` steps — not loops over remote/CPU-heavy
  per-file work in the same way; not mentioned as slow.

## Design

### Common pattern: `xargs -P`

Every sequential `while read` / `for image in ...` loop is restructured as:
build a newline- or NUL-delimited list of work items, then
`xargs -P "$CONCURRENCY" -I{} bash -c '... process one item ...' _ {}`.

Two constraints shape every script below:

1. **No shared mutable state across workers.** `xargs -P` children are
   separate processes; they cannot increment a parent-shell counter
   (`((i+=1))`) and have it observed by the parent. Any accounting that
   currently relies on that (progress counters, `count`/`countNew` in
   `copy_images.sh`) is replaced by: each worker prints one machine-parseable
   result line to stdout, and the parent derives final counts from that
   captured output after `xargs` completes.
2. **Concurrent appends to shared report files are safe as-is.** Every
   `>>` write in these scripts is a single line well under `PIPE_BUF`
   (4096 bytes on Linux), so concurrent `>>` appends from multiple workers
   cannot interleave mid-line. No locking needed.

Concurrency is configurable via environment variables, each with a sensible
default, settable from the Makefile or the CI workflow without editing the
scripts:

| Script | Variable | Default | Rationale |
|---|---|---|---|
| `download-from-pokemondb.sh` | `DOWNLOAD_CONCURRENCY` | `8` | network-bound; be a reasonably polite client to a third-party server |
| `convert.sh`, `convert_png_webp.sh` | `CONVERT_CONCURRENCY` | `$(nproc)` | CPU-bound |
| `copy_images.sh` | `COPY_CONCURRENCY` | `$(nproc)` | CPU/IO-bound (`identify`, `compare`) |

### `download-from-pokemondb.sh`

The per-line body (download regular + shiny for one pokémon, check for
empty/failed downloads, log failures) becomes a worker function, exported
with `export -f` and invoked via `xargs -P "$DOWNLOAD_CONCURRENCY"`. The
worker prints one line per pokémon processed (e.g. `OK bulbasaur` /
`FAIL bulbasaur regular`); failures still get appended to
`report_failed_regular.txt` / `report_failed_shiny.txt` exactly as today.

The existing modulo-based progress printer (tuned for a known sequential
order and rate) is dropped — completion order isn't deterministic under
`xargs -P` — in favor of letting each worker's one-line result print as it
finishes.

Fix in passing: `report_done.txt` is created but never written to (only
failures are ever appended to a report file), so today's final
`totalCount=$(wc -l < report_done.txt)` always reports `0`. Since this
whole accounting section is being rewritten to be parallel-safe anyway,
`totalCount` is derived directly from `$count` (already computed via
`wc -l < "$list"`) instead.

### `convert.sh` / `convert_png_webp.sh`

`find <dir> -name '*.png' -print0 | xargs -0 -P "$CONVERT_CONCURRENCY" ...`
calling a worker that runs `cwebp` on one file if the `.webp` doesn't
already exist. Same settings (`-q 100 -z 9 -m 6`), same skip-if-exists
check, just parallel. Final "Done N of M" line is derived from counting
worker output lines instead of an in-loop counter.

### `copy_images.sh`

Worker processes one source image: validate → decide accept/review path →
`compare` against existing destination (if any) → copy if different, and
prints a tagged result line (`NEW <file>` / `COPY <file>` / `SKIP <file>` /
`REJECT <file>: <reason>`) instead of mutating `count`/`countNew`/`i`
in-loop. The parent captures all worker output and derives
`count`/`countNew`/`i` by counting tagged lines, then prints the **exact
same** final summary line format:
`"Done %d (%d new) of %d %s, in %ds\n"` — this format is asserted verbatim
by `test_copy_images.sh` (`assert_matches ... 'Done 1 \(1 new\) of 1 foo,'`),
so it must not change. Per-file `Reject`/`Copy` log lines keep their current
wording too, since the test also asserts on absence/presence of certain
substrings in output.

### CI: cache `images/temp/`

In `update-images.yml`, add an `actions/cache@v4` step before the
"Download, convert and copy" step, caching
`src/download-from-pokemon-db/images/temp/` (which holds both the
downloaded `.png` and the converted `.webp` — one cache covers both the
download and convert steps):

```yaml
- name: Cache pokemondb temp images
  uses: actions/cache@v4
  with:
    path: src/download-from-pokemon-db/images/temp
    key: pdb-images-temp-${{ github.run_id }}
    restore-keys: pdb-images-temp-
```

The key never matches exactly (it includes the unique `run_id`), so restore
always falls through to `restore-keys` and picks the most recent previous
cache; a new cache is saved at the end of every run. Combined with the
scripts' existing skip-if-exists checks, a run where `pokemons-list.txt` is
unchanged since the last run ends up skipping nearly all downloads and
conversions.

## Error handling

Unchanged in spirit: failed downloads still land in
`report_failed_regular.txt` / `report_failed_shiny.txt`; `copy_images.sh`
rejects still land in `review/...` with a `Reject:` log line. Parallelizing
doesn't change what counts as success/failure, only how results are
collected (worker stdout instead of inline counters).

## Testing

No formal test suite exists for `download-from-pokemondb.sh` or
`convert.sh`; verification is manual:
- Run `download-from-pokemondb.sh` against
  `pokemons-list-extract.txt` (66 lines) before/after, diff the resulting
  files and failure reports, compare wall-clock time.
- Run `convert.sh` on a small subset, diff resulting `.webp` files
  (byte-identical expected, same `cwebp` flags).
- Run `copy_images.sh`'s existing `test_copy_images.sh` — must pass
  unmodified, since it asserts exact output text.
- Time the full `make pdb_dl pdb_convert pdb_copy` chain before/after on
  the full list as the overall before/after comparison.
