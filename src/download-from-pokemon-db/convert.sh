#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1

startAll=`date +%s`

printf "Start %s on %s\n" "$file" "$dimension"

iTotal=0
iDone=0
images="$SCRIPT_DIR/images/temp/$file/*.png"
for image in $images
do
    filename=${image%.*}

    destinationFile="$filename.webp"

    if [ ! -f "$destinationFile" ]; then
        cwebp -quiet -q 100 -z 9 -m 6 "$image" -o "$destinationFile" 
        ((iDone+=1))

        printf "%d\n" "$iDone"
    fi
    
    ((iTotal+=1))
done

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$file" $runtime

exit