#!/bin/bash
set -euo pipefail

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_BASE_IMAGE:=$scriptDir/base.png}"
: "${BANNER_LAYERS_DIR:=$scriptDir/layers}"
: "${BANNER_CONFIG_FILE:?BANNER_CONFIG_FILE must be set (point to a JSON file with slug -> [layer] mappings)}"
: "${BANNER_LAYER_MODES_FILE:=$(dirname "$BANNER_LAYERS_DIR")/layer-modes.json}"
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

# layer-modes.json is optional: an absent file means every layer composites
# with plain Over at full opacity, same as before this feature existed.
if [ -f "$BANNER_LAYER_MODES_FILE" ]; then
    jqParseError=$(jq empty "$BANNER_LAYER_MODES_FILE" 2>&1 >/dev/null) || {
        printf "ERROR: layer modes file is not valid JSON: %s\n%s\n" "$BANNER_LAYER_MODES_FILE" "$jqParseError" >&2
        exit 1
    }

    if ! jq -e 'type == "object" and all(.[]; type == "object")' "$BANNER_LAYER_MODES_FILE" > /dev/null; then
        printf "ERROR: layer modes file must be an object mapping each layer name to a {mode, opacity} object: %s\n" "$BANNER_LAYER_MODES_FILE" >&2
        exit 1
    fi

    # Every key must reference a real layer file -- otherwise a typo'd or
    # stale entry (e.g. a renamed layer) would silently never apply,
    # instead of failing loudly like every other validation in this script.
    unknownLayers=""
    while IFS= read -r name; do
        [ -f "$BANNER_LAYERS_DIR/$name.png" ] || unknownLayers+="$name"$'\n'
    done < <(jq -r 'keys[]' "$BANNER_LAYER_MODES_FILE")
    if [ -n "$unknownLayers" ]; then
        printf "ERROR: layer modes file references layer(s) with no matching file in %s:\n%s" "$BANNER_LAYERS_DIR" "$unknownLayers" >&2
        exit 1
    fi

    if ! jq -e '[.[] | select(has("mode")) | .mode | type == "string"] | all' "$BANNER_LAYER_MODES_FILE" > /dev/null; then
        printf "ERROR: layer modes file has a non-string \"mode\" value: %s\n" "$BANNER_LAYER_MODES_FILE" >&2
        exit 1
    fi

    composeList=$(convert -list compose)
    invalidModes=""
    while IFS= read -r mode; do
        grep -qxF "$mode" <<< "$composeList" || invalidModes+="$mode"$'\n'
    done < <(jq -r '.[] | select(has("mode")) | .mode' "$BANNER_LAYER_MODES_FILE" | sort -u)
    if [ -n "$invalidModes" ]; then
        printf "ERROR: layer modes file has unsupported \"mode\" value(s) (must be one of ImageMagick's -compose operators: %s):\n%s" "$(tr '\n' ' ' <<< "$composeList")" "$invalidModes" >&2
        exit 1
    fi

    if ! jq -e '[.[] | select(has("opacity")) | .opacity | type == "number" and . >= 0 and . <= 100] | all' "$BANNER_LAYER_MODES_FILE" > /dev/null; then
        printf "ERROR: layer modes file has an \"opacity\" value outside 0-100: %s\n" "$BANNER_LAYER_MODES_FILE" >&2
        exit 1
    fi
fi

mkdir -p "$destDir"

mapfile -t slugs < <(jq -r 'keys[]' "$BANNER_CONFIG_FILE")

DONE_FILE=$(mktemp)
SKIP_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE" "$SKIP_FILE"' EXIT

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

            mode="Over"
            opacity="100"
            if [ -f "$BANNER_LAYER_MODES_FILE" ]; then
                mode=$(jq -r --arg l "$layer" '.[$l].mode // "Over"' "$BANNER_LAYER_MODES_FILE")
                opacity=$(jq -r --arg l "$layer" '.[$l].opacity // 100' "$BANNER_LAYER_MODES_FILE")
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
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE BANNER_LAYER_MODES_FILE DONE_FILE SKIP_FILE

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
