#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

SOURCE_DIR="$SCRIPT_DIR/temp/koenig-source"
STAGE_DIR="$SCRIPT_DIR/temp/final/small"
MANIFEST="$SCRIPT_DIR/temp/manifest.tsv"
ALIASES="$SCRIPT_DIR/resources/aliases.csv"
SLUGS="$SCRIPT_DIR/resources/pokenini-slugs.txt"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/regular" "$STAGE_DIR/shiny"

jq -r '
  .[] | .icons[] |
  select(.regular != null and (.regular.modifiers // []) == [] and (.regular.categories // []) == []) |
  (
    ([.regular.slug, "regular", (.regular.name + ".png")] | @tsv),
    (if .shiny != null and (.shiny.modifiers // []) == ["shiny"] then
        ([.regular.slug, "shiny", (.shiny.name + ".png")] | @tsv)
     else empty end)
  )
' "$SOURCE_DIR/data.json" > "$MANIFEST"

matched=0
aliased=0
missing=0
missingList=()

while IFS= read -r pokeniniSlug; do
    [ -z "$pokeniniSlug" ] && continue

    sourceSlug="$pokeniniSlug"
    viaAlias=0
    aliasTarget=$(awk -F, -v s="$pokeniniSlug" '$1==s{print $2; exit}' "$ALIASES")
    if [ -n "$aliasTarget" ]; then
        sourceSlug="$aliasTarget"
        viaAlias=1
    fi

    regularFile=$(awk -F'\t' -v s="$sourceSlug" '$1==s && $2=="regular"{print $3; exit}' "$MANIFEST")
    shinyFile=$(awk -F'\t' -v s="$sourceSlug" '$1==s && $2=="shiny"{print $3; exit}' "$MANIFEST")

    if [ -z "$regularFile" ]; then
        missing=$((missing+1))
        missingList+=("$pokeniniSlug")
        continue
    fi

    cp "$SOURCE_DIR/$regularFile" "$STAGE_DIR/regular/$pokeniniSlug.png"
    if [ -n "$shinyFile" ]; then
        cp "$SOURCE_DIR/$shinyFile" "$STAGE_DIR/shiny/$pokeniniSlug.png"
    fi

    matched=$((matched+1))
    [ "$viaAlias" -eq 1 ] && aliased=$((aliased+1))
done < "$SLUGS"

total=$((matched+missing))
printf "Matched %d/%d slugs (%d via alias, %d unmatched)\n" "$matched" "$total" "$aliased" "$missing"
if [ "$missing" -gt 0 ]; then
    printf "Unmatched (falls through to placeholders): %s\n" "${missingList[*]}"
fi
