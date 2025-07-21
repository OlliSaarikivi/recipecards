#!/usr/bin/env bash
set -euo pipefail

PDF="build/main.pdf"
SLUGS="build/slugs.txt"
OUTDIR="card"
TEMPLATE="app_template.html"
OUTPUT="app.html"
PLACEHOLDER='/* $SLUGS_MAP */'

mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*

# --- Parse category titles to arrays of slugs, and page->slug map ---
declare -A cat_slugs
declare -A slugs

while IFS=':' read -r page category_title recipe_slug; do
    [[ -z "$recipe_slug" ]] && continue
    slugs[$page]="$recipe_slug"
    if [[ -z "${cat_slugs[$category_title]:-}" ]]; then
        cat_slugs["$category_title"]="$recipe_slug"
    else
        cat_slugs["$category_title"]+=",${recipe_slug}"
    fi
done < "$SLUGS"

# --- Compose JS object ---
jsmap="const slugs = {\n"
for cat in "${!cat_slugs[@]}"; do
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

awk -v map="$jsmap" -v placeholder="$PLACEHOLDER" '
    { 
      if (index($0, placeholder)) {
        sub(placeholder, map)
        print
      } else print
    }
' "$TEMPLATE" > "$OUTPUT"

echo "Wrote JS map into $OUTPUT"

# --- Extract and convert PDFs ---
pages=("${!slugs[@]}")
IFS=$'\n' sorted_pages=($(sort -n <<<"${pages[*]}"))
minpage=${sorted_pages[0]}
maxpage=${sorted_pages[-1]}

pdfseparate -f "$minpage" -l "$maxpage" "$PDF" "$OUTDIR/card-%d.pdf"

for page in $(seq "$minpage" "$maxpage"); do
    slug="${slugs[$page]}"
    pdf="$OUTDIR/card-$page.pdf"
    jpg_base="$OUTDIR/${slug}"
    svg_file="$OUTDIR/${slug}.svg"
    pdftoppm -jpeg -jpegopt quality=95 -rx 400 -ry 400 -singlefile "$pdf" "$jpg_base"
    pdf2svg "$pdf" "$svg_file" 1
    rm "$pdf"
done

echo "PDF fonts for debugging"
pdffonts "$PDF"

echo "All JPEGs and SVGs exported to $OUTDIR/"
