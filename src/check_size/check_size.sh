#!/bin/bash

# Usage : ./check_images.sh /chemin/vers/repertoire largeur hauteur
# Exemple : ./check_images.sh ./images 128 128

DIR="${1}"
EXPECTED_WIDTH="${2}"
EXPECTED_HEIGHT="${3}"

if ! command -v identify >/dev/null 2>&1; then
    echo "Erreur : la commande 'identify' (ImageMagick) est requise."
    exit 1
fi

find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -not -path '*/thumb/*' | while read -r img; do
    size=$(identify -format "%w %h" "$img" 2>/dev/null)
    if [ -z "$size" ]; then
        echo "Impossible de lire l'image : $img"
        continue
    fi
    width=$(echo "$size" | awk '{print $1}')
    height=$(echo "$size" | awk '{print $2}')

    if [ "$width" -ne "$EXPECTED_WIDTH" ] || [ "$height" -ne "$EXPECTED_HEIGHT" ]; then
        echo "❌ Mauvaises dimensions : $img ($width x $height)"
    fi
done
