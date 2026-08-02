#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

directories=("images/banner" "images/big/regular" "images/big/shiny" "images/small/regular" "images/small/shiny")

for dir in "${directories[@]}"
do
    "$SCRIPT_DIR/../convert_webp/convert_webp.sh" "$dir"
done

exit
