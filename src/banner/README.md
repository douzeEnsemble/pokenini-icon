# Banner

Banner are made with https://pixlr.com/fr/e/#editor.

Use `.pxz` file to have layers and data.
Export to `.png` into `public/img/dex/banner`

## Layer blend mode and opacity

By default, `generate.sh` composites every layer with plain alpha blending
(GIMP's "Normal" mode, full opacity). A layer can instead be composited with
a specific blend mode and/or opacity by adding an entry to the optional
`src/banner/layer-modes.json` file:

```json
{
  "shiny": { "mode": "ColorDodge", "opacity": 80 }
}
```

- `mode` and `opacity` are both optional; an entry (or the whole file) can
  be absent, which keeps the default Normal / 100% behavior.
- `opacity` is an integer 0-100.
- `mode` must be one of ImageMagick's actual `-compose` operators (run
  `convert -list compose` to see the full list) -- `generate.sh` validates
  this at run time and fails loudly on a typo.

### French (GIMP) -> `mode` correspondence

GIMP's blend-mode names are localized in French. Look up the mode you
picked in GIMP's Layers dialog here to find the value to write in
`layer-modes.json` (extracted from GIMP 3's own French translation
catalog, non-legacy modes only):

| GIMP (FR) | GIMP (EN) | `mode` value |
|---|---|---|
| Normal | Normal | *(omit -- default)* |
| Dissoudre | Dissolve | `Dissolve` |
| Multiplier | Multiply | `Multiply` |
| Écran | Screen | `Screen` |
| Éclaircir | Dodge | `ColorDodge` |
| Assombrir | Burn | `ColorBurn` |
| Éclaircir seulement | Lighten only | `Lighten` |
| Assombrir seulement | Darken only | `Darken` |
| Différence | Difference | `Difference` |
| Superposer | Overlay | `Overlay` |
| Lumière dure | Hard light | `HardLight` |
| Lumière douce | Soft light | `SoftLight` |
| Mélange dur | Hard mix | `HardMix` |
| Exclusion | Exclusion | `Exclusion` |
| Lumière vive | Vivid light | `VividLight` |
| Lumière linéaire | Linear light | `LinearLight` |
| Lumière ponctuelle | Pin light | `PinLight` |
| Assombrissement linéaire | Linear burn | `LinearBurn` |
| Remplacer | Replace | `Replace` |

Note: GIMP's "Éclaircir" is the `Dodge` mode, not `Screen` (GIMP's
`Screen` mode is labeled "Écran" in French) -- easy to mix up.

> This doc now describes the design source only (the `.pxz`/`.xcf` layered
> file and how it's edited). The export/generation step is automated by
> `src/banner_generate/generate.sh` (see the "Banner generator" section in
> the repo's top-level `README.md`) — export each layer as a named PNG,
> reference it in the slug -> layers config (fetched live from
> `pokenini-api`'s `GET /istration/dex-banner-layers` endpoint in CI, not
> committed to this repo), and the script composites the final banners
> instead of manual pixlr/GIMP exports.

## Exporting layers from `pokenini_banner.xcf`

`pokenini_banner.xcf` is a deeply nested tree of GIMP groups (up to 4
levels deep, ~265 named items total as of writing). Most banners are
composed by toggling the visibility of several named layers/groups at
once, not a single flat layer — see the note left in the design spec
history for the full tree dump if needed.

`export_layers.sh` exports one or more named layers/groups (by exact
GIMP layer name) as a single flattened, transparent PNG at full canvas
size, ready to drop into `src/banner/layers/<name>.png`:

```bash
src/banner/export_layers.sh <output.png> "<layer-or-group-name>" ["<layer-or-group-name>" ...]

# examples
src/banner/export_layers.sh src/banner/layers/shiny.png "Shiny filter"
src/banner/export_layers.sh src/banner/layers/megashiny.png "Mega Symbol" "Shiny filter"
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

**What layer names apply to which banner slug is tracked in
`pokenini-api`'s Dex tab "Banner Layers" column (fetched at generation
time via `GET /istration/dex-banner-layers`), not in this repo.** That
correspondence still needs to be worked out by hand (or with help) once
this file's layer tree has been reorganized — see the "Banner generator"
section in the top-level `README.md` for how the mapping is fetched.

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
