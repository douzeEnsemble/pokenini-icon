#!/bin/bash
set -euo pipefail

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_BASE_IMAGE:=$scriptDir/base.png}"
: "${BANNER_LAYERS_DIR:=$(dirname "$scriptDir")/banner/layers}"
: "${BANNER_CONFIG_FILE:?BANNER_CONFIG_FILE must be set (point to a JSON file with slug -> [layer] mappings)}"
: "${CONVERT_CONCURRENCY:=$(nproc)}"

destDir=${1:-images/dex/banner}

if [ ! -f "$BANNER_BASE_IMAGE" ]; then
    printf "ERROR: base image not found: %s\n" "$BANNER_BASE_IMAGE" >&2
    exit 1
fi

if [ ! -f "$BANNER_CONFIG_FILE" ]; then
    printf "ERROR: banner config file not found: %s\n" "$BANNER_CONFIG_FILE" >&2
    exit 1
fi

jqParseError=$(jq empty "$BANNER_CONFIG_FILE" 2>&1 >/dev/null) || {
    printf "ERROR: banner config file is not valid JSON: %s\n%s\n" "$BANNER_CONFIG_FILE" "$jqParseError" >&2
    exit 1
}

if ! jq -e 'type == "object" and all(.[]; type == "array" and all(.[]; type == "string"))' "$BANNER_CONFIG_FILE" > /dev/null; then
    printf "ERROR: banner config file must be an object mapping each slug to an array of layer-name strings: %s\n" "$BANNER_CONFIG_FILE" >&2
    exit 1
fi

if ! jq -e '[keys[] | test("^[A-Za-z0-9_-]+$")] | all' "$BANNER_CONFIG_FILE" > /dev/null; then
    printf "ERROR: banner config file contains a slug with unsafe characters (only letters, digits, underscore and hyphen are allowed): %s\n" "$BANNER_CONFIG_FILE" >&2
    exit 1
fi

if ! jq -e '[.[][] | test("^[A-Za-z0-9_-]+$")] | all' "$BANNER_CONFIG_FILE" > /dev/null; then
    printf "ERROR: banner config file contains a layer name with unsafe characters (only letters, digits, underscore and hyphen are allowed): %s\n" "$BANNER_CONFIG_FILE" >&2
    exit 1
fi

emptySlugs=$(jq -r 'to_entries[] | select(.value | length == 0) | .key' "$BANNER_CONFIG_FILE")
if [ -n "$emptySlugs" ]; then
    printf "ERROR: the following banner(s) have an empty layer list ([]) in %s and would produce a blank (base-only) image:\n%s\n" "$BANNER_CONFIG_FILE" "$emptySlugs" >&2
    exit 1
fi

mkdir -p "$destDir"

mapfile -t slugs < <(jq -r 'keys[]' "$BANNER_CONFIG_FILE")

# List of ImageMagick's actual -compose operators, used to validate any
# per-layer "mode" value below. Computed once here (not per-layer) since
# spawning `convert -list compose` is not free and generate_one() runs
# once per layer per banner across parallel xargs workers.
COMPOSE_LIST_FILE=$(mktemp)
convert -list compose > "$COMPOSE_LIST_FILE"

DONE_FILE=$(mktemp)
SKIP_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE" "$SKIP_FILE" "$COMPOSE_LIST_FILE"' EXIT

generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile tmpFile

    # Layer references are validated unconditionally, even for a slug
    # that turns out to already exist below -- this catches a layer
    # renamed/removed in the config after its banner was generated,
    # instead of silently never re-checking it once the PNG exists.
    layersOutput=$(jq -r --arg slug "$slug" '.[$slug][]' "$BANNER_CONFIG_FILE") || {
        printf "ERROR: failed to read layers for banner '%s' from %s\n" "$slug" "$BANNER_CONFIG_FILE" >&2
        exit 1
    }
    if [ -n "$layersOutput" ]; then
        while IFS= read -r layer; do
            layerFile="$BANNER_LAYERS_DIR/$layer.png"
            if [ ! -f "$layerFile" ]; then
                printf "ERROR: layer '%s' referenced by banner '%s' not found: %s\n" "$layer" "$slug" "$layerFile" >&2
                exit 1
            fi

            # Optional per-layer sidecar file (<layer>.json next to
            # <layer>.png). Its name IS the layer name, so unlike a shared
            # mapping file there is no separate key that could typo or go
            # stale -- a layer with no sidecar file just defaults below.
            layerModeFile="$BANNER_LAYERS_DIR/$layer.json"
            mode="Over"
            opacity="100"
            if [ -f "$layerModeFile" ]; then
                jqParseError=$(jq empty "$layerModeFile" 2>&1 >/dev/null) || {
                    printf "ERROR: layer mode file for '%s' is not valid JSON: %s\n%s\n" "$layer" "$layerModeFile" "$jqParseError" >&2
                    exit 1
                }
                if ! jq -e 'type == "object"' "$layerModeFile" > /dev/null; then
                    printf "ERROR: layer mode file for '%s' must be a JSON object: %s\n" "$layer" "$layerModeFile" >&2
                    exit 1
                fi
                if jq -e 'has("mode") and (.mode | type != "string")' "$layerModeFile" > /dev/null; then
                    printf "ERROR: layer mode file for '%s' has a non-string \"mode\" value: %s\n" "$layer" "$layerModeFile" >&2
                    exit 1
                fi
                mode=$(jq -r '.mode // "Over"' "$layerModeFile")
                if ! grep -qxF "$mode" "$COMPOSE_LIST_FILE"; then
                    printf "ERROR: layer mode file for '%s' has an unsupported \"mode\" value (must be one of ImageMagick's -compose operators: %s): %s\n" "$layer" "$(tr '\n' ' ' < "$COMPOSE_LIST_FILE")" "$mode" >&2
                    exit 1
                fi
                if jq -e 'has("opacity") and (.opacity | type != "number" or . < 0 or . > 100)' "$layerModeFile" > /dev/null; then
                    printf "ERROR: layer mode file for '%s' has an \"opacity\" value outside 0-100: %s\n" "$layer" "$layerModeFile" >&2
                    exit 1
                fi
                opacity=$(jq -r '.opacity // 100' "$layerModeFile")
            fi

            # Opacity < 100 scales the layer's alpha channel before the
            # compose step -- the standard way to fade a blend-mode layer
            # toward the destination, same as a GIMP/Photoshop layer's
            # mode + opacity combination.
            if [ "$opacity" = "100" ]; then
                args+=("$layerFile")
            else
                # LC_NUMERIC=C: under a locale like fr_FR, awk's printf
                # emits a comma decimal separator ("0,4000"), which
                # ImageMagick's -evaluate multiply can't parse -- it
                # silently zeroes the alpha instead of scaling it.
                fraction=$(LC_NUMERIC=C awk -v p="$opacity" 'BEGIN { printf "%.4f", p / 100 }')
                args+=("(" "$layerFile" -channel A -evaluate multiply "$fraction" +channel ")")
            fi
            args+=(-compose "$mode" -composite)
        done <<< "$layersOutput"
    fi

    if [ -f "$destinationFile" ]; then
        printf "SKIP: %s already exists: %s\n" "$slug" "$destinationFile"
        printf "SKIP\n" >> "$SKIP_FILE"
        return 0
    fi

    # Write to a hidden temp file first, then rename into place -- a
    # `convert` that's interrupted or fails partway (disk space race,
    # non-fatal delegate warning) never leaves a truncated file at
    # $destinationFile, where the skip-existing check above would treat
    # it as done and never touch it again.
    tmpFile=$(mktemp --suffix=.png "$destDir/.${slug}.XXXXXX")
    if ! convert "${args[@]}" "$tmpFile"; then
        rm -f "$tmpFile"
        exit 1
    fi
    mv -f "$tmpFile" "$destinationFile"
    printf "GENERATED: %s\n" "$slug"
    printf "DONE\n" >> "$DONE_FILE"
}
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE COMPOSE_LIST_FILE DONE_FILE SKIP_FILE

xargsExit=0
if [ "${#slugs[@]}" -gt 0 ]; then
    printf '%s\0' "${slugs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'set -euo pipefail; generate_one "$@"' _ {} || xargsExit=$?
fi

iDone=$(wc -l < "$DONE_FILE")
iSkip=$(wc -l < "$SKIP_FILE")
printf "Generated %d of %d banners (%d already existed, skipped)\n" "$iDone" "${#slugs[@]}" "$iSkip"

if [ "$xargsExit" -ne 0 ]; then
    exit 1
fi
