#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cat=$1
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

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

i=0
count=0
countNew=0
images="$SCRIPT_DIR/images/final/big/$file/*.png"
for image in $images
do
    filename=${image##*/}

    destinationFile="images/big/$file/$filename"

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