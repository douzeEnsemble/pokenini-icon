#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

list=$1

cat=$2

case $cat in

    "r")
        downloadRegulars=true
        downloadShinies=false
        ;;

    "s")
        downloadRegulars=false
        downloadShinies=true
        ;;

    "rs")
        downloadRegulars=true
        downloadShinies=true
        ;;

    "sr")
        downloadRegulars=true
        downloadShinies=true
        ;;

    *)
        downloadRegulars=true
        downloadShinies=true
        ;;
esac

special_download_pokemon() {
    local remote_name="$1"
    local local_name="$2"
    local base_url="https://img.pokemondb.net/sprites/$3"

    echo $base_url/normal/$remote_name.png;

    if [ "$downloadRegulars" = true ] && [ ! -f "$SCRIPT_DIR/images/temp/others/regular/$local_name.png" ]; then
        wget --no-cache "$base_url/normal/$remote_name.png" -O "$SCRIPT_DIR/images/temp/others/regular/$local_name.png"
        sed -i "/^$remote_name,/d" "$SCRIPT_DIR/report_failed_regular.txt"
    fi

    if [ "$downloadShinies" = true ] && [ ! -f "$SCRIPT_DIR/images/temp/others/shiny/$local_name.png" ]; then
        wget --no-cache "$base_url/shiny/$remote_name.png" -O "$SCRIPT_DIR/images/temp/others/shiny/$local_name.png"
        sed -i "/^$remote_name,/d" "$SCRIPT_DIR/report_failed_shiny.txt"
    fi
}

special_pokemons=(
    "pikachu-cosplay|pikachu-cosplay|omega-ruby-alpha-sapphire/dex"
    # "pikachu-rockstar|pikachu-rock-star|go"
    "pikachu-popstar|pikachu-pop-star|go"
    "pikachu-phd|pikachu-phd|go"
    "pikachu-libre|pikachu-libre|go"
    # "pichu-spiky-eared|pichu-spiky-eared|heartgold-soulsilver"
    "floette-eternal|floette-eternal|ultra-sun-ultra-moon"
)

# Downloads
## Create needed directories
mkdir -p "$SCRIPT_DIR/images/temp/home/regular"
mkdir -p "$SCRIPT_DIR/images/temp/home/shiny"
mkdir -p "$SCRIPT_DIR/images/temp/others/regular"
mkdir -p "$SCRIPT_DIR/images/temp/others/shiny"

echo '' > "$SCRIPT_DIR/report_done.txt"
echo '' > "$SCRIPT_DIR/report_failed_regular.txt"
echo '' > "$SCRIPT_DIR/report_failed_shiny.txt"

startAll=`date +%s`
count=$(wc -l < $list)
i=1

# Add an empty line at the end of the file
echo '' >> "$list"
## Download from list
while read line; do
    IFS=',' read -a data <<< "$line"

    sourceFileName=${data[0]}
    targetFileName=${data[1]}

    if [ "$downloadRegulars" = true ]
    then
        if [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/home/normal/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/regular/"

            if [ -f "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/home/regular/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/home/regular/$targetFileName.png" ]; then
            echo $line >> "$SCRIPT_DIR/report_failed_regular.txt"
        fi
    fi

    if [ "$downloadShinies" = true ]
    then
        case "$sourceFileName" in
            minior-*)
                echo "Arrêt car sourceFileName commence par 'minior-' ($sourceFileName)"
                break
                ;;
        esac

        if [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
            wget --no-cache -q "https://img.pokemondb.net/sprites/home/shiny/$sourceFileName.png" -P "$SCRIPT_DIR/images/temp/home/shiny/"

            if [ -f "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" ] && [ "$sourceFileName" != "$targetFileName" ]; then
                mv "$SCRIPT_DIR/images/temp/home/shiny/$sourceFileName.png" "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png"
            fi
        fi

        if [ ! -f "$SCRIPT_DIR/images/temp/home/shiny/$targetFileName.png" ]; then
            echo $line >> "$SCRIPT_DIR/report_failed_shiny.txt"
        fi
    fi

    runtime=$(((`date +%s`)-startAll))

    if [[
        ($count -gt 500 && 0 -eq $(expr $i % 100))
        || ($count -lt 500 && $count -gt 50 && 0 -eq $(expr $i % 10))
        || ($count -lt 50 && $count -gt 5)
    ]]
    then
        printf "%d / %d, %d%%, %ss\n" "$i" "$count" $(( $i*100/$count )) "$runtime"
    fi

    ((i+=1))
done < $list

# Specials
for entry in "${special_pokemons[@]}"; do
    remote_name="${entry%%|*}"
    rest="${entry#*|}"
    local_name="${rest%%|*}"
    url="${rest#*|}"
    special_download_pokemon "$remote_name" "$local_name" "$url"
done

# Copy
if [ "$downloadRegulars" = true ]
then
    mkdir -p "$SCRIPT_DIR/images/final/big/regular"
    cp -R --update=none "$SCRIPT_DIR/images/temp/home/regular"/* "$SCRIPT_DIR/images/final/big/regular/"
    cp -R --update=none "$SCRIPT_DIR/images/temp/others/regular"/* "$SCRIPT_DIR/images/final/big/regular/"
fi
if [ "$downloadShinies" = true ]
then
    mkdir -p "$SCRIPT_DIR/images/final/big/shiny"
    cp -R --update=none "$SCRIPT_DIR/images/temp/home/shiny"/* "$SCRIPT_DIR/images/final/big/shiny"
    cp -R --update=none "$SCRIPT_DIR/images/temp/others/shiny"/* "$SCRIPT_DIR/images/final/big/shiny"
fi

runtime=$(((`date +%s`)-startAll))

sed -i '/^$/d' "$SCRIPT_DIR/report_done.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_regular.txt"
sed -i '/^$/d' "$SCRIPT_DIR/report_failed_shiny.txt"

totalCount=$(wc -l < "$SCRIPT_DIR/report_done.txt")
failRegulars=$(wc -l < "$SCRIPT_DIR/report_failed_regular.txt")
failShinies=$(wc -l < "$SCRIPT_DIR/report_failed_shiny.txt")

if [ "$downloadRegulars" = true ] && [ "$downloadShinies" = true ]
then
    ((totalCount+=$totalCount))
fi

printf "Done %d, %d+%d, in %ds\n" "$totalCount" "$failRegulars" "$failShinies" "$runtime"

exit