#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cat=$1
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

fuzz=$2

# Cut

startAll=`date +%s`

#for file in 'regulars' 'shinies'
for file in ${types[@]};
do
    echo "Start $file"

    ## Create needed directories
    mkdir -p "$SCRIPT_DIR/images/$file"
    mkdir -p "$SCRIPT_DIR/images/temp/$file"

    count=$(ls $SCRIPT_DIR/images/temp/$file/tile_*.png |wc -l)
    i=1
    echo "Cut out number line AND Crop the icon, replace pixel corner, remove background for each pokemons"
    TILES="$SCRIPT_DIR/images/temp/$file/tile_*.png"
    for tile in $TILES
    do
        filename=${tile##*/}

        # Crop icon only
        #convert "$SCRIPT_DIR/images/temp/$file/$filename" \
        #    -crop 68X68+1+28 +repage -fill "#68b77d" \
        #    -draw "rectangle 0,0 5,5" -alpha set -channel RGBA -fuzz 45% \
        #    -fill none -floodfill +0+0 white "$SCRIPT_DIR/images/$file/$filename.png"
        convert "$SCRIPT_DIR/images/temp/$file/$filename" \
            -crop 68X68+1+28 +repage -fill "#68b77d" \
            -draw "rectangle 0,0 5,5" -alpha set -channel RGBA \
            -fuzz "$fuzz%" -fill none -opaque "#6fb881" \
            "$SCRIPT_DIR/images/$file/$filename.png"

        # nbPixel=$(convert "$SCRIPT_DIR/images/$file/$filename.png" \
        #     -fill black -fuzz "$fuzz%" +opaque "#6fb881" \
        #     -fill white -fuzz "$fuzz%" -opaque "#6fb881" \
        #     -print "%[fx:w*h*mean]"   null:)

        # if [[ "$nbPixel" -ge 5 ]]
        # then
        #     convert "$SCRIPT_DIR/images/$file/$filename.png" -fuzz "$fuzz%" \
        #         -transparent "#6fb881" "$SCRIPT_DIR/images/$file/$filename.png"
        # fi

        runtime=$(((`date +%s`)-startAll))

        echo "$i / $count, $(( $i*100/$count ))%, ${runtime}s"

        ((i+=1))
    done

    runtime=$(((`date +%s`)-startAll))

    echo "Done $count $file", in ${runtime}s
done
