#!/bin/bash
set -euo pipefail

# Exports one or more named layers/groups from the layered source file
# (pokenini_banner.xcf) as a single flattened, transparent PNG at full
# canvas size -- suitable for dropping into
# src/banner_generate/layers/<name>.png for use by generate.sh.
#
# Usage:
#   src/banner/export_layers.sh <output.png> <layer-or-group-name> [<layer-or-group-name> ...]
#
# Example:
#   src/banner/export_layers.sh src/banner_generate/layers/shiny.png "Shiny filter"
#   src/banner/export_layers.sh src/banner_generate/layers/megashiny.png "Mega Symbol" "Shiny filter"
#
# A named group exports everything inside it (its whole subtree), exactly
# as if you'd shown that group in the GIMP UI. Everything else in the file
# stays hidden, regardless of its saved visibility state in the .xcf.
#
# Requires GIMP 3 (tested against the snap package: /snap/bin/gimp).
#
# Known GIMP-3-batch-mode gotchas this script works around -- see
# src/banner/README.md for the full writeup:
#   - piping the script via stdin (`-b -` with redirected/backgrounded
#     stdin) silently reads from /dev/full instead of the real script in
#     sandboxed/backgrounded shells, so the script is passed as a single
#     `-b "<scheme code>"` argument instead.
#   - `gimp-item-is-group` (not `-id-is-group`).
#   - `gimp-image-get-layers` returns `(#(id ...))`, a 1-element list
#     wrapping the id vector -- not `(count . vector)` like GIMP 2.10.
#   - `file-png-export` takes only `(run-mode image path)` in GIMP 3 --
#     no drawable argument (it exports the image's composite), and no
#     PNG option arguments (interlace/compression/etc.) in this minimal
#     form.
#   - `flush-output` is unbound in GIMP's bundled TinyScheme; rely on
#     `close-output-port` to flush instead.
#   - the snap-confined `gimp` binary can only read/write paths under
#     $HOME (via snap's "home" interface) -- NOT /tmp, and not arbitrary
#     paths outside $HOME. <output.png> must resolve to somewhere under
#     $HOME (a path inside this repo checkout is fine); a /tmp path will
#     silently fail to write with no error message at all.

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_XCF_FILE:=$scriptDir/pokenini_banner.xcf}"

if [ "$#" -lt 2 ]; then
    printf "Usage: %s <output.png> <layer-or-group-name> [<layer-or-group-name> ...]\n" "$0" >&2
    exit 1
fi

outputPath=$1
shift

if [ ! -f "$BANNER_XCF_FILE" ]; then
    printf "ERROR: source .xcf not found: %s\n" "$BANNER_XCF_FILE" >&2
    exit 1
fi

# Build the scheme `(list "name1" "name2" ...)` form, escaping backslashes
# and double quotes in each name so odd layer names can't break the script.
itemNamesScheme=""
for name in "$@"; do
    escaped=${name//\\/\\\\}
    escaped=${escaped//\"/\\\"}
    itemNamesScheme+="\"$escaped\" "
done

progressLog=$(mktemp "$scriptDir/.export_progress.XXXXXX")
trap 'rm -f "$progressLog"' EXIT

scheme=$(cat <<EOF
(define outport (open-output-file "$progressLog"))
(define (log msg) (display msg outport) (newline outport))

(define xcf-path "$BANNER_XCF_FILE")
(define item-names (list $itemNamesScheme))
(define output-path "$outputPath")

(log "loading source image")
(define src-image (car (gimp-file-load RUN-NONINTERACTIVE xcf-path "src.xcf")))
(log "source loaded")

(define work-image (car (gimp-image-duplicate src-image)))
(gimp-image-delete src-image)

(define top (car (gimp-image-get-layers work-image)))

; Find target-name under items, returning the full ancestor chain (a list
; of item ids, target first, each ancestor group after it, up to but not
; including top-level) if found, or #f. This does NOT touch visibility --
; visibility is applied in one pass at the end (see apply-visibility
; below), so that searching for a second item-name can never re-hide
; anything a prior item-name's search already decided to keep visible.
(define (find-chain items target-name)
  (let loop ((i 0))
    (if (>= i (vector-length items))
        #f
        (let* ((lid (vector-ref items i))
               (name (car (gimp-item-get-name lid))))
          (if (string=? name target-name)
              (list lid)
              (if (= (car (gimp-item-is-group lid)) 1)
                  (let ((sub (find-chain (car (gimp-item-get-children lid)) target-name)))
                    (if sub
                        (cons lid sub)
                        (loop (+ i 1))))
                  (loop (+ i 1))))))))

(define keep-visible '())

(for-each
  (lambda (item-name)
    (let ((chain (find-chain top item-name)))
      (if chain
          (set! keep-visible (append chain keep-visible))
          (log (string-append "shown: " item-name "  *** NOT FOUND ***")))
      (if chain
          (log (string-append "shown: " item-name)))))
  item-names)

; Single sweep over the WHOLE tree: every item's visibility is set purely
; from whether it's in keep-visible. This is what prevents a sibling that
; was saved visible=TRUE in the .xcf from leaking into the composite --
; every item not on a requested path is explicitly forced invisible here,
; not just left untouched.
(define (apply-visibility items)
  (let loop ((i 0))
    (if (< i (vector-length items))
        (begin
          (let ((lid (vector-ref items i)))
            (gimp-item-set-visible lid (if (memv lid keep-visible) TRUE FALSE))
            (if (= (car (gimp-item-is-group lid)) 1)
                (apply-visibility (car (gimp-item-get-children lid)))))
          (loop (+ i 1))))))
(apply-visibility top)

(define merged (car (gimp-image-merge-visible-layers work-image CLIP-TO-IMAGE)))
(gimp-layer-resize-to-image-size merged)
(log "merged + resized")

(file-png-export RUN-NONINTERACTIVE work-image output-path)
(log "export done")

(gimp-image-delete work-image)
(close-output-port outport)
(gimp-quit 0)
EOF
)

timeout 480 gimp -i --batch-interpreter=plug-in-script-fu-eval -b "$scheme" 2>&1 | grep -iE "error|unbound" >&2 || true

cat "$progressLog"

if grep -q "NOT FOUND" "$progressLog"; then
    printf "ERROR: one or more layer/group names were not found (see *** NOT FOUND *** above) -- output was still written but is missing content.\n" >&2
    exit 1
fi

if ! grep -q "export done" "$progressLog"; then
    printf "ERROR: export did not complete -- see errors above.\n" >&2
    exit 1
fi
