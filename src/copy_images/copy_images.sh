#!/bin/bash
shopt -s nullglob

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

category=$1
sourceDir=$2
file=$3
expectedWidth=$4
expectedHeight=$5

: "${COPY_CONCURRENCY:=$(nproc)}"

startAll=`date +%s`

printf "Start %s (%sx%s)\n" "$file" "$expectedWidth" "$expectedHeight"

RESULTS_FILE=$(mktemp)
trap 'rm -f "$RESULTS_FILE"' EXIT

copy_one() {
    local image="$1"
    local filename=${image##*/}
    local destinationFile="images/$category/$file/$filename"
    local targetFile reason
    local countDifference=99999999999
    local isNew=0

    if reason=$("$SCRIPT_DIR/../validate_image/validate_image.sh" "$image" "$expectedWidth" "$expectedHeight"); then
        targetFile="$destinationFile"
    else
        targetFile="review/$category/$file/$filename"
        printf "Reject %s: %s\n" "$filename" "$reason"
    fi

    mkdir -p "$(dirname "$targetFile")"

    if test -f "$targetFile"
    then
        countDifference=$(compare -metric AE "$image" "$targetFile" null: 2>&1)
    else
        isNew=1
    fi

    if [[ $countDifference -ne 0 ]]
    then
        cp "$image" "$targetFile"
        printf "Copy %s\n" "$filename"
        printf "COPY\n" >> "$RESULTS_FILE"
        [ "$isNew" -eq 1 ] && printf "NEW\n" >> "$RESULTS_FILE"
    fi

    printf "SEEN\n" >> "$RESULTS_FILE"
}
export -f copy_one
export SCRIPT_DIR category file expectedWidth expectedHeight RESULTS_FILE

images=("$sourceDir"/*.{png,webp})

if [ "${#images[@]}" -gt 0 ]; then
    printf '%s\0' "${images[@]}" | xargs -0 -P "$COPY_CONCURRENCY" -I{} bash -c 'copy_one "$@"' _ {}
fi

i=$(grep -c '^SEEN$' "$RESULTS_FILE")
count=$(grep -c '^COPY$' "$RESULTS_FILE")
countNew=$(grep -c '^NEW$' "$RESULTS_FILE")

runtime=$(((`date +%s`)-startAll))

printf "Done %d (%d new) of %d %s, in %ds\n" "$count" "$countNew" "$i" "$file" $runtime

exit
