#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

list=$1

cat=$2

case $cat in

    "r")
        downloadRegulars=true
        downloadShinies=false
        ;;

    "s")
        downloadRegulars=false
        downloadShinies=true
        ;;

    "rs")
        downloadRegulars=true
        downloadShinies=true
        ;;

    "sr")
        downloadRegulars=true
        downloadShinies=true
        ;;

    *)
        downloadRegulars=true
        downloadShinies=true
        ;;
esac

# Downloads
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/temp/home/regular"
mkdir -p "$SCRIPT_DIR/images/temp/home/shiny"
mkdir -p "$SCRIPT_DIR/images/temp/sv/regular"
mkdir -p "$SCRIPT_DIR/images/temp/sv/shiny"
mkdir -p "$SCRIPT_DIR/images/temp/others/regular"
mkdir -p "$SCRIPT_DIR/images/temp/others/shiny"

echo '' > "$SCRIPT_DIR/report_done.txt"
echo '' > "$SCRIPT_DIR/report_failed_regular.txt"
echo '' > "$SCRIPT_DIR/report_failed_shiny.txt"

startAll=`date +%s`
count=$(wc -l < $list)
i=1

# Add an empty line at the end of the file
echo '' >> "$list"
## Download from list
while read line; do
    IFS=',' read -a data <<< "$line"

    sourceFileName=${data[0]}
    targetFileName=${data[1]}

    echo $line >> "$SCRIPT_DIR/report_done.txt"

    if [ "$downloadRegulars" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/scarlet-violet/normal/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/sv/regular/"

            if [ -f "$SCRIPT_DIR/images/temp/sv/regular/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/sv/regular/$sourceFileName.png" "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/home/normal/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/regular/"

            if [ -f "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/sv/regular/$targetFileName.png" ] && [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
            echo $line >> "$SCRIPT_DIR/report_failed_regular.txt"
        fi
    fi

    if [ "$downloadShinies" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/scarlet-violet/shiny/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/sv/shiny/"

            if [ -f "$SCRIPT_DIR/images/temp/sv/shiny/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/sv/shiny/$sourceFileName.png" "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/home/shiny/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/shiny/"

            if [ -f "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/sv/shiny/$targetFileName.png" ] && [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
            echo $line >> "$SCRIPT_DIR/report_failed_shiny.txt"
        fi
    fi

    runtime=$(((`date +%s`)-startAll))

    if [[
        ($count -gt 500 && 0 -eq $(expr $i % 100))
        || ($count -lt 500 && $count -gt 50 && 0 -eq $(expr $i % 10))
        || ($count -lt 50 && $count -gt 5)
    ]]
    then
        printf "%d / %d, %d%%, %ss\n" "$i" "$count" $(( $i*100/$count )) "$runtime"
    fi

    ((i+=1))
done < $list

# Specials
if [ "$downloadRegulars" = true -a ! -f "$SCRIPT_DIR/images/temp/others/regular/floette-eternal.png" ]; then
    wget --no-cache -q https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/normal/floette-eternal.png -P "$SCRIPT_DIR/images/temp/others/regular"
fi

if [ "$downloadShinies" = true -a ! -f "$SCRIPT_DIR/images/temp/others/shiny/floette-eternal.png" ]; then
    wget --no-cache -q https://img.pokemondb.net/sprites/ultra-sun-ultra-moon/shiny/floette-eternal.png -P "$SCRIPT_DIR/images/temp/others/shiny"
fi

# Copy
if [ "$downloadRegulars" = true ]
then
    mkdir -p "$SCRIPT_DIR/images/final/big/regular"
    cp -nR "$SCRIPT_DIR/images/temp/home/regular"/* "$SCRIPT_DIR/images/final/big/regular/"
    cp -nR "$SCRIPT_DIR/images/temp/sv/regular"/* "$SCRIPT_DIR/images/final/big/regular/"
    cp -nR "$SCRIPT_DIR/images/temp/others/regular"/* "$SCRIPT_DIR/images/final/big/regular/"
fi
if [ "$downloadShinies" = true ]
then
    mkdir -p "$SCRIPT_DIR/images/final/big/shiny"
    cp -nR "$SCRIPT_DIR/images/temp/home/shiny"/* "$SCRIPT_DIR/images/final/big/shiny"
    cp -nR "$SCRIPT_DIR/images/temp/sv/shiny"/* "$SCRIPT_DIR/images/final/big/shiny"
    cp -nR "$SCRIPT_DIR/images/temp/others/shiny"/* "$SCRIPT_DIR/images/final/big/shiny"
fi

runtime=$(((`date +%s`)-startAll))

sed -i '/^$/d' "$SCRIPT_DIR/report_done.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_regular.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_shiny.txt"

totalCount=$(wc -l < "$SCRIPT_DIR/report_done.txt")
failRegulars=$(wc -l < "$SCRIPT_DIR/report_failed_regular.txt")
failShinies=$(wc -l < "$SCRIPT_DIR/report_failed_shiny.txt")

if [ "$downloadRegulars" = true ] && [ "$downloadShinies" = true ]
then
    ((totalCount+=$totalCount))
fi

printf "Done %d, %d+%d, in %ds\n" "$totalCount" "$failRegulars" "$failShinies" "$runtime"

exit