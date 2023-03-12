#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

namesMatchesFile=$1

cat=$2
case $cat in

    "r")
        types=('regulars')
        ;;

    "s")
        types=('shinies')
        ;;

    "rs")
        types=('regulars' 'shinies')
        ;;

    "sr")
        types=('shinies' 'regulars')
        ;;

    *)
        types=('regulars' 'shinies')
        ;;
esac

echo '' > "$SCRIPT_DIR/report_spritenotfound.txt"

echo '' >> "$namesMatchesFile"
IFS=','
for file in ${types[@]};
do
    echo "Start $file"

    case $file in
        "shinies")
            finalDir='shiny'
            ;;

        "regulars")
            finalDir='regular'
            ;;
    esac

    mkdir -p "$SCRIPT_DIR/images/final/small/$finalDir"

    while read line; do
        IFS=, read -a data <<< "$line"

        spriteName=${data[0]}
        iconName=${data[1]}

        if [[ $line == "" || $spriteName == "" || $iconName == "" ]]
        then
            continue
        fi

        cp "$SCRIPT_DIR/images/$file/$spriteName.png" \
            "$SCRIPT_DIR/images/final/small/$finalDir/$iconName.png" \
            2>> "$SCRIPT_DIR/report_spritenotfound.txt"
    done < $namesMatchesFile
done
IFS=''
