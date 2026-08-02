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

: "${DOWNLOAD_CONCURRENCY:=8}"

# Downloads
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/temp/regular"
mkdir -p "$SCRIPT_DIR/images/temp/shiny"

echo '' > "$SCRIPT_DIR/report_failed_regular.txt"
echo '' > "$SCRIPT_DIR/report_failed_shiny.txt"

startAll=`date +%s`
count=$(wc -l < "$list")

download_one() {
    local line="$1"
    local data

    IFS=',' read -a data <<< "$line"

    local sourceFileName=${data[0]}
    local sourceDirName=${data[1]}
    local targetFileName=${data[2]}

    if [ -z "$sourceFileName" ] || [ -z "$sourceDirName" ] || [ -z "$targetFileName" ]
    then
        return
    fi

    if [ "$downloadRegulars" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/normal/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            rm -f "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
            echo "$line" >> "$SCRIPT_DIR/report_failed_regular.txt"
        fi
    fi

    if [ "$downloadShinies" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/shiny/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            rm -f "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
            echo "$line" >> "$SCRIPT_DIR/report_failed_shiny.txt"
        fi
    fi
}
export -f download_one
export SCRIPT_DIR downloadRegulars downloadShinies

cat "$list" | xargs -d '\n' -P "$DOWNLOAD_CONCURRENCY" -I{} bash -c 'download_one "$@"' _ {}

runtime=$(((`date +%s`)-startAll))

sed -i '/^$/d' "$SCRIPT_DIR/report_failed_regular.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_shiny.txt"

failRegulars=$(wc -l < "$SCRIPT_DIR/report_failed_regular.txt")
failShinies=$(wc -l < "$SCRIPT_DIR/report_failed_shiny.txt")

totalCount=$count
if [ "$downloadRegulars" = true ] && [ "$downloadShinies" = true ]
then
    ((totalCount+=$totalCount))
fi

printf "Done %d, %d+%d, in %ds\n" "$totalCount" "$failRegulars" "$failShinies" "$runtime"

exit
