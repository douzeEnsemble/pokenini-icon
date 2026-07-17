#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

"$SCRIPT_DIR/../copy_images/copy_images.sh" big "$SCRIPT_DIR/images/temp/$file" "$file" 256 256
