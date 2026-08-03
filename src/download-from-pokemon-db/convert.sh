#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

"$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$SCRIPT_DIR/images/temp/$file" "$file"
