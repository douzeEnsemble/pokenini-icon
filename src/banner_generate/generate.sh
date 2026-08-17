#!/bin/bash
set -euo pipefail

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_BASE_IMAGE:=$scriptDir/base.png}"
: "${BANNER_LAYERS_DIR:=$scriptDir/layers}"
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

DONE_FILE=$(mktemp)
SKIP_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE" "$SKIP_FILE"' EXIT

generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile

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
            args+=("$layerFile" -composite)
        done <<< "$layersOutput"
    fi

    convert "${args[@]}" "$destinationFile"
    printf "DONE\n" >> "$DONE_FILE"
}
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE DONE_FILE SKIP_FILE

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
