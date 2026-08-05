#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

directories=("images/dex/banner" "images/pokemon/big/regular" "images/pokemon/big/shiny" "images/pokemon/small/regular" "images/pokemon/small/shiny")

for dir in "${directories[@]}"
do
    "$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$dir"
done

exit
