#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

category=$1
sourceDir=$2
file=$3
expectedWidth=$4
expectedHeight=$5

startAll=`date +%s`

printf "Start %s (%sx%s)\n" "$file" "$expectedWidth" "$expectedHeight"

i=0
count=0
countNew=0
for image in "$sourceDir"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/$category/$file/$filename"

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" "$expectedWidth" "$expectedHeight"); then
        targetFile="$destinationFile"
    else
        targetFile="review/$category/$file/$filename"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    mkdir -p "$(dirname "$targetFile")"

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
