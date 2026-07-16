#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

i=0
count=0
countNew=0
for image in "$SCRIPT_DIR/images/temp/$file"/*.{png,webp}
do
    filename=${image##*/}

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" 256 256); then
        targetFile="images/big/$file/$filename"
    else
        targetFile="review/big/$file/$filename"
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