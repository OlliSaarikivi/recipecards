#!/usr/bin/env bash
set -euo pipefail

SLUGS="build_svg/slugs.txt"
APP_DIR="app_template"
TEMPLATE="app_template/index.html"
OUTDIR="recipes"
OUTPUT="$OUTDIR/index.html"
PLACEHOLDER='SLUGS_MAP'
GIT_HASH=$(git rev-parse --short HEAD)
SW_TEMPLATE="$APP_DIR/sw.js"
SW_OUTPUT="$OUTDIR/sw.js"

mkdir -p "$OUTDIR"
cp -r $APP_DIR/* "$OUTDIR/"

# --- Parse category titles to arrays of slugs, and page->slug map ---
declare -A cat_slugs
declare -A slugs
cat_order=()

while IFS=':' read -r page category_title recipe_slug; do
    [[ -z "$recipe_slug" ]] && continue
    slugs[$page]="$recipe_slug"
    if [[ -z "${cat_slugs[$category_title]+_}" ]]; then
        cat_order+=("$category_title")
        cat_slugs["$category_title"]="$recipe_slug"
    else
        cat_slugs["$category_title"]+=",${recipe_slug}"
    fi
done < "$SLUGS"


# --- Compose JS object ---
jsmap="const slugs = {\n"
for cat in "${cat_order[@]}"; do
    jsmap+="  \"${cat}\": [\n"
    IFS=',' read -ra arr <<< "${cat_slugs[$cat]}"
    for slug in "${arr[@]}"; do
        jsmap+="    \"${slug}\",\n"
    done
    jsmap+="  ],\n"
done
jsmap+="};"

# --- Replace placeholder in template and write output ---
if ! grep -q "$PLACEHOLDER" "$TEMPLATE"; then
    echo "Error: Placeholder $PLACEHOLDER not found in $TEMPLATE"
    exit 1
fi

echo -e "$jsmap" > tmp_slugs_map.js

perl -0777 -pe '
  BEGIN {
    open MAP, "tmp_slugs_map.js" or die $!;
    local $/;
    $map = <MAP>;
    close MAP;
  }
  s/\Q'"$PLACEHOLDER"'\E/$map/s;
' "$TEMPLATE" > "$OUTPUT"

rm tmp_slugs_map.js

sed "s/__GIT_HASH__/$GIT_HASH/g" "$SW_TEMPLATE" > "$SW_OUTPUT"

echo "Exported app."
