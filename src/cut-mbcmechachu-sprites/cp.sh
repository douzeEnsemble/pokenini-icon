#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

size=$1
file=$2

case "$size" in
    small)
        expectedWidth=68
        expectedHeight=68
        ;;
    big)
        expectedWidth=256
        expectedHeight=256
        ;;
    *)
        echo "Unknown size '$size' (expected 'small' or 'big')" >&2
        exit 1
        ;;
esac

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

i=0
count=0
countNew=0
for image in "$SCRIPT_DIR/temp/final/$size/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/$size/$file/$filename"

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" "$expectedWidth" "$expectedHeight"); then
        targetFile="$destinationFile"
    else
        targetFile="review/$size/$file/$filename"
        mkdir -p "$(dirname "$targetFile")"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    countDifference=99999999999
    if test -f "$targetFile"
    then
        countDifference=$(compare -metric AE "$image" "$targetFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$targetFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done

runtime=$(((`date +%s`)-startAll))

printf "Done %d (%d new) of %d %s, in %ds\n" "$count" "$countNew" "$i" "$file" $runtime

exit