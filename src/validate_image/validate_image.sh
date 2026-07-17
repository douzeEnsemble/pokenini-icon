#!/bin/bash

file="$1"
expectedWidth="$2"
expectedHeight="$3"

if [ ! -f "$file" ]; then
    echo "missing file"
    exit 1
fi

if [ ! -s "$file" ]; then
    echo "empty file"
    exit 1
fi

info=$(identify -format "%m %w %h" "$file" 2>/dev/null)
if [ -z "$info" ]; then
    echo "unreadable/corrupt"
    exit 1
fi

format=$(echo "$info" | awk '{print $1}')
width=$(echo "$info" | awk '{print $2}')
height=$(echo "$info" | awk '{print $3}')

extension="${file##*.}"
extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

case "$extension" in
    png)
        expectedFormat="PNG"
        ;;
    webp)
        expectedFormat="WEBP"
        ;;
    jpg|jpeg)
        expectedFormat="JPEG"
        ;;
    *)
        echo "unsupported extension: .$extension"
        exit 1
        ;;
esac

if [ "$format" != "$expectedFormat" ]; then
    echo "format mismatch: expected $expectedFormat, got $format"
    exit 1
fi

if [ "$width" -ne "$expectedWidth" ] || [ "$height" -ne "$expectedHeight" ]; then
    echo "bad dimensions: ${width}x${height} (expected ${expectedWidth}x${expectedHeight})"
    exit 1
fi

exit 0
