
#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

IMAGICK="convert"

file='regulars'

# Cut
icons="$SCRIPT_DIR/images/$file/*.png"
nb=0
sum=0
i=0
for icon in $icons
do
    filename=${icon##*/}

    ## Crop number line
    nbPixel=$($IMAGICK "$icon" -fill black -fuzz 5% +opaque "#6fb881" \
        -fill white -fuzz 5% -opaque "#6fb881" \
        -print "%[fx:w*h*mean]"   null:)

    ((sum+=nbPixel))

    if [[ "$nbPixel" -ge 5 ]]
    then
        ((nb+=1))
    fi

    ((i+=1))
done

avg=$((sum / i))

echo "$i images analysed, $nb if at least 5 green pixels. AVG $avg"