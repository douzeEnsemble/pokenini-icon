#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Downloads
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/temp/home/regular"
mkdir -p "$SCRIPT_DIR/images/temp/home/shiny"
mkdir -p "$SCRIPT_DIR/images/temp/sv/regular"
mkdir -p "$SCRIPT_DIR/images/temp/sv/shiny"
mkdir -p "$SCRIPT_DIR/images/temp/others/regular"
mkdir -p "$SCRIPT_DIR/images/temp/others/shiny"

echo '' > "$SCRIPT_DIR/report.all.txt"
echo '' > "$SCRIPT_DIR/report.regular.txt"
echo '' > "$SCRIPT_DIR/report.shiny.txt"

## Download from list
IFS=';'
while read line; do
    read -a data <<< "$line"

    sourceFileName=${data[0]}
    targetFileName=${data[1]}

    echo $line

    echo $line > "$SCRIPT_DIR/report.all.txt"

    if [ ! -f "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png" ]; then
        echo "Download https://img.pokemondb.net/sprites/scarlet-violet/normal/$sourceFileName.png"

        wget --no-cache -q "https://img.pokemondb.net/sprites/scarlet-violet/normal/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/sv/regular/"

        if [ -f "$SCRIPT_DIR/images/temp/sv/regular/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
            mv "$SCRIPT_DIR/images/temp/sv/regular/$sourceFileName.png" "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png"
        fi
    fi

    if [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
        echo "Download https://img.pokemondb.net/sprites/home/normal/$sourceFileName.png"

        wget --no-cache -q "https://img.pokemondb.net/sprites/home/normal/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/regular/"

        if [ -f "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
            mv "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png"
        fi
    fi

    if [ ! -f "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png" ] && [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
        echo $line >> "$SCRIPT_DIR/report.regular.txt"
    fi

    if [ ! -f "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png" ]; then
        echo "Download https://img.pokemondb.net/sprites/scarlet-violet/shiny/$sourceFileName.png"

        wget --no-cache -q "https://img.pokemondb.net/sprites/scarlet-violet/shiny/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/sv/shiny/"

        if [ -f "$SCRIPT_DIR/images/temp/sv/shiny/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
            mv "$SCRIPT_DIR/images/temp/sv/shiny/$sourceFileName.png" "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png"
        fi
    fi

    if [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
        echo "Download https://img.pokemondb.net/sprites/home/shiny/$sourceFileName.png"

        wget --no-cache -q "https://img.pokemondb.net/sprites/home/shiny/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/shiny/"

        if [ -f "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
            mv "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png"
        fi
    fi

    if [ ! -f "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png" ] && [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
        echo $line >> "$SCRIPT_DIR/report.shiny.txt"
    fi
done <$1
IFS=''

# Specials
if [ ! -f "$SCRIPT_DIR/images/temp/others/regular/floette-eternal.png" ]; then
    echo "Download https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/normal/floette-eternal.png"

    wget --no-cache -q https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/normal/floette-eternal.png -P "$SCRIPT_DIR/images/temp/others/regular"
fi
if [ ! -f "$SCRIPT_DIR/images/temp/others/shiny/floette-eternal.png" ]; then
    echo "Download https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/shiny/floette-eternal.png"

    wget --no-cache -q https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/shiny/floette-eternal.png -P "$SCRIPT_DIR/images/temp/others/shiny"
fi

# Copy
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/final/big/regular"
mkdir -p "$SCRIPT_DIR/images/final/big/shiny"

## Copy home sprites
cp -nR "$SCRIPT_DIRimages/temp/home/regular/*" "$SCRIPT_DIRimages/final/big/regular"
cp -nR "$SCRIPT_DIRimages/temp/home/shiny/*" "$SCRIPT_DIRimages/final/big/shiny"

## Copy sv sprites
cp -nR "$SCRIPT_DIRimages/temp/sv/regular/*" "$SCRIPT_DIRimages/final/big/regular"
cp -nR "$SCRIPT_DIRimages/temp/sv/shiny/*" "$SCRIPT_DIRimages/final/big/shiny"

## Copy others sprites
cp -nR "$SCRIPT_DIRimages/temp/others/regular/*" "$SCRIPT_DIRimages/final/big/regular"
cp -nR "$SCRIPT_DIRimages/temp/others/shiny/*" "$SCRIPT_DIRimages/final/big/shiny"
