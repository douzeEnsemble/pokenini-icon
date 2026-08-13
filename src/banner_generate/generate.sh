#!/bin/bash
set -euo pipefail

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${BANNER_BASE_IMAGE:=$scriptDir/base.png}"
: "${BANNER_LAYERS_DIR:=$scriptDir/layers}"
: "${BANNER_CONFIG_FILE:=$scriptDir/banners.json}"
: "${CONVERT_CONCURRENCY:=$(nproc)}"

destDir=${1:-images/dex/banner}

if [ ! -f "$BANNER_BASE_IMAGE" ]; then
    printf "ERROR: base image not found: %s\n" "$BANNER_BASE_IMAGE" >&2
    exit 1
fi

mkdir -p "$destDir"

mapfile -t slugs < <(jq -r 'keys[]' "$BANNER_CONFIG_FILE")

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

generate_one() {
    local slug="$1"
    local destinationFile="$destDir/$slug.png"
    local args=("$BANNER_BASE_IMAGE")
    local layer layerFile

    while IFS= read -r layer; do
        layerFile="$BANNER_LAYERS_DIR/$layer.png"
        if [ ! -f "$layerFile" ]; then
            printf "ERROR: layer '%s' referenced by banner '%s' not found: %s\n" "$layer" "$slug" "$layerFile" >&2
            exit 1
        fi
        args+=("$layerFile" -composite)
    done < <(jq -r --arg slug "$slug" '.[$slug][]' "$BANNER_CONFIG_FILE")

    convert "${args[@]}" "$destinationFile"
    printf "DONE\n" >> "$DONE_FILE"
}
export -f generate_one
export destDir BANNER_BASE_IMAGE BANNER_LAYERS_DIR BANNER_CONFIG_FILE DONE_FILE

xargsExit=0
if [ "${#slugs[@]}" -gt 0 ]; then
    printf '%s\0' "${slugs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'set -euo pipefail; generate_one "$@"' _ {} || xargsExit=$?
fi

iDone=$(wc -l < "$DONE_FILE")
printf "Generated %d of %d banners\n" "$iDone" "${#slugs[@]}"

if [ "$xargsExit" -ne 0 ]; then
    exit 1
fi
