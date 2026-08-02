#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

: "${CONVERT_CONCURRENCY:=$(nproc)}"

directories=("images/banner" "images/big/regular" "images/big/shiny" "images/small/regular" "images/small/shiny")

startAll=`date +%s`

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

for dir in "${directories[@]}"
do
    printf "Start %s\n" "$dir"

    DONE_FILE=$(mktemp)
    export DONE_FILE

    pngs=("$dir"/*.png)

    if [ "${#pngs[@]}" -gt 0 ]; then
        printf '%s\0' "${pngs[@]}" | xargs -0 -P "$CONVERT_CONCURRENCY" -I{} bash -c 'convert_one "$@"' _ {}
    fi

    i=$(wc -l < "$DONE_FILE")
    rm -f "$DONE_FILE"

    runtime=$(((`date +%s`)-startAll))

    printf "Done %d %s, in %ds\n" "$i" "$dir" $runtime
done

exit
