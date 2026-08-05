#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

expectedWidth=$(awk -F ' *= *' '/^icon_width/{print $2; exit}' "$SCRIPT_DIR/config.ini")
expectedHeight=$(awk -F ' *= *' '/^icon_height/{print $2; exit}' "$SCRIPT_DIR/config.ini")

"$SCRIPT_DIR/../copy_images/copy_images.sh" pokemon/small "$SCRIPT_DIR/temp/final/small/$file" "$file" "$expectedWidth" "$expectedHeight"
