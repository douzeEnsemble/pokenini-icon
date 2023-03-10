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

echo '' > "$SCRIPT_DIR/report_equals.txt"
echo '' > "$SCRIPT_DIR/report_notequals.txt"

startAll=`date +%s`

#for file in 'regulars' 'shinies'
for file in ${types[@]};
do
    echo "Start $file"

    count=$(ls $SCRIPT_DIR/images/temp/$file/number_*.png |wc -l)
    countEmpty=0
    i=1
    echo "Cut out number line AND Crop the icon, replace pixel corner, remove background for each pokemons"
    TILES="$SCRIPT_DIR/images/temp/$file/tile_*.png"
    for tile in $TILES
    do
        filename=${tile##*/}

        # Detect number line text
        $TESSERACT "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.png" \
            "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}" \
            --psm 7 -c page_separator="" \
            -c load_system_dawg=false -c load_freq_dawg=false \
            -c tessedit_char_whitelist="GMFUXYN0123456789-" \
            1>/dev/null 2>&1

        cp "$SCRIPT_DIR/images/temp/$file//number_${filename%.*}.txt" "$SCRIPT_DIR/images/temp/$file//number_${filename%.*}_original.txt"

        originalNumber=$(cat "$SCRIPT_DIR/images/temp/$file//number_${filename%.*}_original.txt")
        number=$(cat "$SCRIPT_DIR/images/temp/$file//number_${filename%.*}.txt")

        if [[ $originalNumber == $number ]]
        then
            printf '%s %-10s == %-10s\n' "$filename" "$originalNumber" "$number" >> "$SCRIPT_DIR/report_equals.txt"
        else
            printf '%s %-10s != %-10s\n' "$filename" "$originalNumber" "$number" >> "$SCRIPT_DIR/report_notequals.txt"
        fi

        if [[ $number == "" || $number == "0" || $number == "00" ]]
        then
            ((countEmpty+=1))
            ((i+=1))

            continue
        fi

        runtime=$(((`date +%s`)-startAll))

        if [[
            ($count -gt 500 && 0 -eq $(expr $i % 100))
            || ($count -lt 500 && $count -gt 50 && 0 -eq $(expr $i % 10))
            || ($count -lt 50 && $count -gt 5)
        ]]
        then
            echo "$i / $count, $(( $i*100/$count ))%, ${runtime}s"
        fi

        ((i+=1))
    done

    runtime=$(((`date +%s`)-startAll))

    echo "Done $count $file", $countEmpty empty or "00" cases, in ${runtime}s
done
