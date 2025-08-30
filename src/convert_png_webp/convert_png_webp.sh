#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

directories=("images/banner" "images/big/regular" "images/big/shiny" "images/small/regular" "images/small/shiny")

startAll=`date +%s`

for dir in "${directories[@]}"
do
    printf "Start %s on %s\n" "$dir"

    i=0
    images="$dir/*.png"
    for image in $images
    do
        filename=${image%.*}
        destinationFile="$filename.webp"
        
        if [ ! -f "$destinationFile" ]; then
            ((i+=1))
            cwebp -quiet -q 100 -z 9 -m 6 "$image" -o "$destinationFile" 
        fi
    done
    
    runtime=$(((`date +%s`)-startAll))

    printf "Done %d %s, in %ds\n" "$i" "$dir" $runtime
done

exit