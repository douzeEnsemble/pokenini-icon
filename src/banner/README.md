# Banner

Banner are made with https://pixlr.com/fr/e/#editor.

Use `.pxz` file to have layers and data.
Export to `.png` into `public/img/dex/banner`

> This doc now describes the design source only (the `.pxz`/`.xcf` layered
> file and how it's edited). The export/generation step is automated by
> `src/banner_generate/generate.sh` (see the "Banner generator" section in
> the repo's top-level `README.md`) — export each layer as a named PNG,
> reference it from `src/banner_generate/banners.json`, and the script
> composites the final banners instead of manual pixlr/GIMP exports.

## Exporting layers from `pokenini_banner.xcf`

`pokenini_banner.xcf` is a deeply nested tree of GIMP groups (up to 4
levels deep, ~265 named items total as of writing). Most banners are
composed by toggling the visibility of several named layers/groups at
once, not a single flat layer — see the note left in the design spec
history for the full tree dump if needed.

`export_layers.sh` exports one or more named layers/groups (by exact
GIMP layer name) as a single flattened, transparent PNG at full canvas
size, ready to drop into `src/banner_generate/layers/<name>.png`:

```bash
src/banner/export_layers.sh <output.png> "<layer-or-group-name>" ["<layer-or-group-name>" ...]

# examples
src/banner/export_layers.sh src/banner_generate/layers/shiny.png "Shiny filter"
src/banner/export_layers.sh src/banner_generate/layers/megashiny.png "Mega Symbol" "Shiny filter"
```

Naming a **group** exports its whole subtree (as if you'd shown that
group in the GIMP UI), regardless of the group's saved visibility state
in the file. Everything else in the file stays hidden. Passing several
names shows all of them simultaneously before flattening, so you can
combine pieces from unrelated branches of the tree into one output PNG.

**Requires GIMP 3** (tested against the `snap` package). The script
exits non-zero and prints `*** NOT FOUND ***` next to any name it
couldn't locate anywhere in the tree — the output file is still written
in that case, but is missing that piece, so always check the exit code
and the printed log, don't just check that a PNG appeared.

**Important — output path must be under `$HOME`.** The snap-confined
`gimp` binary can only read/write paths under `$HOME` (via snap's `home`
interface) — not `/tmp`, and not arbitrary paths outside `$HOME`. A
`/tmp` output path fails to write with **no error message at all**, so
this isn't just a style preference.

**What layer names apply to which banner slug in
`src/banner_generate/banners.json` is not yet mapped out.** That
correspondence still needs to be worked out by hand (or with help) once
this file's layer tree has been reorganized — see the banner generator's
"Placeholder status" note in the top-level `README.md`.

### GIMP 3 batch-mode gotchas this script works around

If you're scripting against this file directly instead of using
`export_layers.sh`, these cost real time to rediscover:

- Piping the script via stdin (`gimp -b -` with redirected/backgrounded
  stdin) silently reads from `/dev/full` instead of the real script
  content, in this sandboxed environment — the whole script has to be
  passed as a single `-b "<scheme code>"` argument instead.
- The group-check function is `gimp-item-is-group`, not
  `gimp-item-id-is-group`.
- `gimp-image-get-layers` returns `(#(id ...))` — a 1-element list
  wrapping the id vector — not `(count . vector)` like GIMP 2.10's PDB.
- `file-png-export` in GIMP 3 takes only `(run-mode image path)` — no
  drawable argument (it exports the image's composite) and none of
  GIMP 2.10's `file-png-save` PNG-option arguments in this minimal form.
- `flush-output` is unbound in GIMP's bundled TinyScheme; rely on
  `close-output-port` to flush buffered writes instead.
- Redirecting GIMP's own stdout to a real file (`gimp ... > file.log`)
  loses everything if the process is killed (e.g. by `timeout`) before
  a clean exit — the writes are fully buffered and never flushed. Pipe
  through another process (`| cat`, `| tee`) instead if you need to see
  output from a run that might not finish cleanly.
