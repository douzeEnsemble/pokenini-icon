#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

IMAGICK="convert"

size=$1
case $size in

    "complete")
        dimension='5520X2720'
        ;;

    "3lines")
        dimension='5520X291'
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

namesMatchesFile=$3

echo '' > "$SCRIPT_DIR/report_equals.txt"
echo '' > "$SCRIPT_DIR/report_notequals.txt"
echo '' > "$SCRIPT_DIR/report_spritenotfound.txt"
echo '' > "$SCRIPT_DIR/report_symbolmistake.txt"

startAll=`date +%s`

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

        numberFilename="$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.png"

        # Detect number line text
        ## Crop number line
        $IMAGICK "$SCRIPT_DIR/images/temp/$file/$filename" -crop 61X10+8+16 +repage \
            -alpha off -fill white -fuzz 5% +opaque "#112037" \
            -fill black -opaque "#112037" \
            -define png:color-type=2 -colorspace sRGB \
            "$numberFilename"

        # Detect number line text
        resultFile="$SCRIPT_DIR/images/temp/$file/number_${filename%.*}_result.txt"
        echo '' > "$resultFile"

        symbols="$SCRIPT_DIR/symbols/*.png"
        for symbolPath in $symbols
        do
            symbolFilename=${symbolPath##*/}
            symbol=${symbolFilename%%.*}

            symbolToAlert=false

            case $symbol in
                '19')
                symbolToAlert=true
                ;;
                '67')
                symbolToAlert=true
                ;;

                '7dm')
                symbol='7-'
                symbolToAlert=true
                ;;
                'dm_')
                symbol='-'
                symbolToAlert=true
                ;;
                'M_')
                symbol='M'
                symbolToAlert=true
                ;;

                'dm')
                symbol='-'
                ;;
                'qmqmqm')
                symbol='E'
                ;;
                *)
                ;;
            esac

            result=$(visgrep $numberFilename $symbolPath)

            if [[ "" == $result ]]
            then
                continue
            fi

            if [ "$symbolToAlert" = true ]
            then
                echo "$symbol in $numberFilename">> "$SCRIPT_DIR/report_symbolmistake.txt"
            fi

            while IFS= read -r line;
            do
                IFS=, read -ra x <<< $line

                echo "$x $symbol" >> "$resultFile"
            done <<< "$result"
        done

        sorted=$(sort -k 1 -h "$resultFile")
        echo "$sorted" > "$resultFile"

        number=''
        while read order symbol;
        do
            number+="$symbol"
        done < $resultFile

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
            $IMAGICK "$SCRIPT_DIR/images/$file/$number.png" -fuzz 2% -transparent "#6fb881" "$SCRIPT_DIR/images/$file/$number.png"
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

    mkdir -p "$SCRIPT_DIR/images/icon_$file"

    while read line; do
        IFS=, read -a data <<< "$line"

        spriteName=${data[0]}
        iconName=${data[1]}

        mv "$SCRIPT_DIR/images/$file/$spriteName.png" \
            "$SCRIPT_DIR/images/icon_$file/$iconName.png" \
            2>> "$SCRIPT_DIR/report_spritenotfound.txt"
    done <$namesMatchesFile

    runtime=$(((`date +%s`)-startAll))

    echo "Done $count $file", $countEmpty empty or "00" cases, in ${runtime}s
done
