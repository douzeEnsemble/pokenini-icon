#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

file=$1
filename=${file##*/}

resultFile="$SCRIPT_DIR/images/temp/results_$filename.txt"
echo '' > "$resultFile"

symbols="$SCRIPT_DIR/symbols/*.png"
for symbolPath in $symbols
do
    symbolFilename=${symbolPath##*/}
    symbol=${symbolFilename%%.*}

    case $symbol in
        '7dm')
        symbol='7-'
        ;;
        'dm')
        symbol='-'
        ;;
        'qm')
        symbol='?'
        ;;
        *)
        ;;
    esac

    echo "====== $symbol ======"

    result=$(visgrep $file $symbolPath)

    echo "result:'$result'"

    if [[ "" == $result ]]
    then
        continue
    fi

    while IFS= read -r line;
    do
        echo "line:'$line'"

        IFS=, read -ra x <<< $line

        echo "$x $symbol"
        echo "$x $symbol" >> "$resultFile"
    done <<< "$result"
done

sorted=$(sort -k 1 -h "$resultFile")
echo "$sorted" > "$resultFile"
cat "$resultFile"

number=''
while read order symbol;
do
    number+="$symbol"
done < $resultFile

echo $number