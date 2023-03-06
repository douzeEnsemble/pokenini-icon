#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

IMAGICK="convert"
TESSERACT="tesseract --psm 7 "

size=$1
# Use 5520X2720 for complete image
# Use 5520X97 for first row only
# Use 758X97 for the first 11 pokemons only
case $size in

    "complete")
        dimension='5520X2720'
        ;;

    "line")
        dimension='5520X97'
        ;;

    "sample")
        dimension='758X97'
        ;;

    *)
        dimension='5520X2720'
        ;;
esac

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

    ## Create needed directories
    mkdir -p "$SCRIPT_DIR/images/$file"
    mkdir -p "$SCRIPT_DIR/images/temp/$file"

    ## Clean file to remove top and left useless pixels
    echo "Clean file to remove top and left useless pixels"
    $IMAGICK "$SCRIPT_DIR/$file.png" -shave 2X281 -repage "$dimension+0+0" "$SCRIPT_DIR/images/temp/$file/paged.png"

    ## Divide file in tiles for each pokemons
    echo "Divide file in tiles for each pokemons"
    $IMAGICK "$SCRIPT_DIR/images/temp/$file/paged.png" -crop 69X97 +repage "$SCRIPT_DIR/images/temp/$file/tile_%04d.png"

    count=$(ls $SCRIPT_DIR/images/temp/$file/tile_*.png |wc -l)
    countEmpty=0
    i=1
    echo "Cut out number line AND Crop the icon, replace pixel corner, remove background for each pokemons"
    TILES="$SCRIPT_DIR/images/temp/$file/tile_*.png"
    for tile in $TILES
    do
        filename=${tile##*/}

        # Detect number line text
        ## Crop number line
        $IMAGICK "$SCRIPT_DIR/images/temp/$file/$filename" -crop 61X10+8+16 +repage \
            -alpha off -fill white -fuzz 5% +opaque "#112037" \
            -fill black -opaque "#112037" \
            -bordercolor white -border 5 \
            -resize 415% -sharpen 0x7 \
            "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.png"

        # Detect number line text
        $TESSERACT "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.png" \
            "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}" \
            --psm 7 -c page_separator="" \
            -c load_system_dawg=false -c load_freq_dawg=false \
            -c tessedit_char_whitelist="GMFUXYN0123456789-" \
            1>/dev/null 2>&1

        cp "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.txt" "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}_original.txt"

        # Fix character detections
        sed -i '/-$/s/$/M/gI' "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.txt"

        originalNumber=$(cat "$SCRIPT_DIR/images/temp/$file/number_${filename%.*}_original.txt")
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

        # Crop icon only
        $IMAGICK "$SCRIPT_DIR/images/temp/$file/$filename" -crop 68X68+1+28 +repage -fill "#68b77d" \
            -draw "rectangle 0,0 5,5" -alpha set -channel RGBA -fuzz 50% \
            -fill none -floodfill +0+0 white "$SCRIPT_DIR/images/$file/$number.png"

        nbPixel=$($IMAGICK "$SCRIPT_DIR/images/$file/$number.png" -fill black -fuzz 5% +opaque "#6fb881" \
            -fill white -fuzz 5% -opaque "#6fb881" \
            -print "%[fx:w*h*mean]"   null:)

        if [[ "$nbPixel" -ge 5 ]]
        then
            $IMAGICK "$SCRIPT_DIR/images/$file/$number.png" -fuzz 5% -transparent "#6fb881" "$SCRIPT_DIR/images/$file/$number.png"
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
