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
mkdir -p "$SCRIPT_DIR/images/temp/regular"
mkdir -p "$SCRIPT_DIR/images/temp/shiny"

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
    sourceDirName=${data[1]}
    targetFileName=${data[2]}

    if [ -z "$sourceFileName" ] || [ -z "$sourceDirName" ] || [ -z "$targetFileName" ]
    then
        continue
    fi

    if [ "$downloadRegulars" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/normal/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/regular/$targetFileName.png" ]; then
            rm  "$SCRIPT_DIR/images/temp/regular/$targetFileName.png"
            echo $line >> "$SCRIPT_DIR/report_failed_regular.txt"
        fi
    fi

    if [ "$downloadShinies" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/$sourceDirName/shiny/$sourceFileName.png" \
                -O "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
        fi

        if [ ! -s "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png" ]; then
            rm  "$SCRIPT_DIR/images/temp/shiny/$targetFileName.png"
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