#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

IMAGICK="convert"
TESSERACT="tesseract"

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

namesMatchesFile=$3

echo '' > "$SCRIPT_DIR/report_spritenotfound.txt"

IFS=','
#for file in 'regulars' 'shinies'
for file in ${types[@]};
do
    echo "Start $file"

    mkdir -p "$SCRIPT_DIR/images/icon_$file"

    while read line; do
        read -a data <<< "$line"

        spriteName=${data[0]}
        iconName=${data[1]}

        cp "$SCRIPT_DIR/images/$file/$spriteName.png" \
            "$SCRIPT_DIR/images/icon_$file/$iconName.png" \
            2>> "$SCRIPT_DIR/report_spritenotfound.txt"
    done <$namesMatchesFile
done
IFS=''
