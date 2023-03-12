#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

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
        file='regular'
        sprites='regulars'
        ;;

    "s")
        file='shiny'
        sprites='shinies'
        ;;

    *)
        echo "R or S you must choose"
        exit
        ;;
esac

namesMatchesFile="$SCRIPT_DIR/pokemons-$file-list.csv"
spritesNotFoundFile="$SCRIPT_DIR/report_${file}_spritenotfound.txt"
symbolMistakesFile="$SCRIPT_DIR/report_${file}_symbolmistake.txt"

if ! test -f "$namesMatchesFile"
then
    printf "File %s not found. I can work without it\n" "$namesMatchesFile"
    exit
fi

# Created reports files
echo '' > "$spritesNotFoundFile"
echo '' > "$symbolMistakesFile"
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/$file"
mkdir -p "$SCRIPT_DIR/images/temp/$file"

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

## Clean file to remove top and left useless pixels
printf "Clean file to remove top and left useless pixels\n"
convert "$SCRIPT_DIR/$sprites.png" -shave 2X281 -repage "$dimension+0+0" "$SCRIPT_DIR/images/temp/$file/paged.png"

## Divide file in tiles for each pokemons
printf "Divide file in tiles for each pokemons\n"
convert "$SCRIPT_DIR/images/temp/$file/paged.png" -crop 69X97 +repage "$SCRIPT_DIR/images/temp/$file/tile_%04d.png"

count=$(ls $SCRIPT_DIR/images/temp/$file/tile_*.png |wc -l)
printf "%d files found\n" "$count"

countEmpty=0
i=1
printf "Cut out number line AND Crop the icon, replace pixel corner, remove background for each pokemons\n"
TILES="$SCRIPT_DIR/images/temp/$file/tile_*.png"
for tile in $TILES
do
    filename=${tile##*/}

    numberFilename="$SCRIPT_DIR/images/temp/$file/number_${filename%.*}.png"

    # Detect number line text
    ## Crop number line
    convert "$SCRIPT_DIR/images/temp/$file/$filename" -crop 61X10+8+16 +repage \
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
            echo "$symbol in $numberFilename">> "$symbolMistakesFile"
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
    convert "$SCRIPT_DIR/images/temp/$file/$filename" \
        -crop 68X68+1+28 +repage -fill "#68b77d" \
        -draw "rectangle 0,0 5,5" -alpha set -channel RGBA \
        -fuzz 5% -fill none -opaque "#6fb881" \
        "$SCRIPT_DIR/images/$file/$number.png"

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
done

mkdir -p "$SCRIPT_DIR/images/final/small/$file"

while read line; do
    IFS=, read -a data <<< "$line"

    spriteName=${data[0]}
    iconName=${data[1]}

    if [[ $line == "" || $spriteName == "" || $iconName == "" ]]
    then
        continue
    fi

    cp "$SCRIPT_DIR/images/$file/$spriteName.png" \
        "$SCRIPT_DIR/images/final/small/$file/$iconName.png" \
        2>> "$spritesNotFoundFile"

done < $namesMatchesFile

runtime=$(((`date +%s`)-startAll))

printf "Done %d %s, in %ds\n" "$count" "$file" $runtime

exit