#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

size=$1
file=$2

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

i=0
count=0
countNew=0
for image in "$SCRIPT_DIR/images/final/$size/$file"/*.{png,webp}
do
    filename=${image##*/}

    destinationFile="images/$size/$file/$filename"

    countDifference=99999999999
    if test -f "$destinationFile"
    then
        countDifference=$(compare -metric AE "$image" "$destinationFile" null: 2>&1)
    else
        ((countNew+=1))
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$destinationFile"
        printf "Copy %s\n" "$filename"

        ((count+=1))
    fi

    ((i+=1))
done

runtime=$(((`date +%s`)-startAll))

printf "Done %d (%d new) of %d %s, in %ds\n" "$count" "$countNew" "$i" "$file" $runtime

exit