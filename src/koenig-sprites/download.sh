#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SHA=$(cat "$SCRIPT_DIR/SOURCE_SHA")
TEMP_DIR="$SCRIPT_DIR/temp"
ARCHIVE="$TEMP_DIR/koenig-source.tar.gz"
SOURCE_DIR="$TEMP_DIR/koenig-source"
STAMP="$TEMP_DIR/.downloaded_sha"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$SHA" ] && [ -f "$SOURCE_DIR/data.json" ]; then
    printf "Already downloaded koenigderluegner/pokemon-sprites @ %s — skipping\n" "$SHA"
    exit 0
fi

rm -rf "$SOURCE_DIR"
mkdir -p "$SOURCE_DIR"

printf "Downloading koenigderluegner/pokemon-sprites @ %s\n" "$SHA"
curl -fsSL -o "$ARCHIVE" "https://codeload.github.com/koenigderluegner/pokemon-sprites/tar.gz/$SHA"

tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --wildcards --strip-components=4 "*/apps/pokemon-sprite/sprites/*.png"
tar -xzf "$ARCHIVE" -C "$SOURCE_DIR" --wildcards --strip-components=3 "*/apps/pokemon-sprite/data.json"

count=$(find "$SOURCE_DIR" -maxdepth 1 -name '*.png' | wc -l)
printf "Extracted %d sprite PNGs and data.json into %s\n" "$count" "$SOURCE_DIR"

echo "$SHA" > "$STAMP"
