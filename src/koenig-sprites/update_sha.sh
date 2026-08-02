#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SHA_FILE="$SCRIPT_DIR/SOURCE_SHA"

current=$(cat "$SHA_FILE")
latest=$(git ls-remote https://github.com/koenigderluegner/pokemon-sprites.git HEAD | cut -f1)

if [ -z "$latest" ]; then
    printf "ERROR: could not resolve latest commit for koenigderluegner/pokemon-sprites\n" >&2
    exit 1
fi

if [ "$current" = "$latest" ]; then
    printf "SOURCE_SHA already up to date (%s)\n" "$current"
    exit 0
fi

printf "Bumping SOURCE_SHA: %s -> %s\n" "$current" "$latest"
printf '%s' "$latest" > "$SHA_FILE"
