#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file='banner'

startAll=`date +%s`

printf "Start %s on %s\n" "$file"

i=0
images="images/banner/*.png"
for image in $images
do
    filename=${image%.*}

    destinationFile="$filename.webp"

    cwebp -quiet -q 100 -z 9 -m 6 "$image" -o "$destinationFile" 
    
    ((i+=1))
done

runtime=$(((`date +%s`)-startAll))

printf "Done %d %s, in %ds\n" "$i" "$file" $runtime

exit