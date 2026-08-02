#!/bin/bash
shopt -s nullglob

directory=$1
label=${2:-$1}

: "${CONVERT_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s\n" "$label"

DONE_FILE=$(mktemp)
trap 'rm -f "$DONE_FILE"' EXIT

convert_one() {
    local image="$1"
    local filename=${image%.*}
    local destinationFile="$filename.webp"

    if [ ! -f "$destinationFile" ]; then
        cwebp -quiet -q 100 -z 9 -m 6 "$image" -o "$destinationFile"
        printf "DONE\n" >> "$DONE_FILE"
    fi
}
export -f convert_one
export DONE_FILE

pngs=("$directory"/*.png)
iTotal=${#pngs[@]}

if [ "$iTotal" -gt 0 ]; then
    printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'convert_one "$@"' _ {}
fi

iDone=$(wc -l < "$DONE_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d of %d %s, in %ds\n" "$iDone" "$iTotal" "$label" $runtime

exit
