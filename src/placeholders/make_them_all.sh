#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cat=$1

case $cat in

    "b")
        dir="big"
        ;;

    "s")
        dir="small"
        ;;

    *)
        echo "b (big) or s (small) you must choose"
        exit
        ;;
esac

limit=${2:-9999}

regularDirPath="$SCRIPT_DIR/../../images/$dir/regular"
shinyDirPath="$SCRIPT_DIR/../../images/$dir/shiny"

destinationDirPath="$SCRIPT_DIR/tmp/$dir/shiny"

mkdir -p "$destinationDirPath"

i=0
count=0
regularIcons="$regularDirPath/*.png"
for iconPath in $regularIcons
do
    filename=${iconPath##*/}

    if [ -f "$shinyDirPath/$filename" ]; then
        ((i+=1))

        continue
    fi

    convert $iconPath matte:- | convert - "$destinationDirPath/$filename"

    convert "$destinationDirPath/$filename" -alpha off -transparent white -alpha on "$destinationDirPath/$filename"

    ((i+=1))
    ((count+=1))

    if [[ $count -ge $limit ]]; then
        break
    fi

done

printf "%d done (over %d in total)\n" $count $i

exit 0