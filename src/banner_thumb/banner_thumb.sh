#!/bin/bash
shopt -s nullglob

sourceDir=$1
destDir=$2
width=${3:-343}

: "${CONVERT_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s\n" "$sourceDir"

mkdir -p "$destDir"

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

thumb_one() {
    local image="$1"
    local filename=${image##*/}
    local destinationFile="$destDir/$filename"

    if [ ! -f "$destinationFile" ]; then
        convert "$image" -resize "${width}x" "$destinationFile"
        printf "DONE\n" >> "$DONE_FILE"
    fi
}
export -f thumb_one
export destDir width DONE_FILE

pngs=("$sourceDir"/*.png)
iTotal=${#pngs[@]}

if [ "$iTotal" -gt 0 ]; then
    printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'thumb_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$sourceDir" $runtime

exit
