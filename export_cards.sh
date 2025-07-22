#!/usr/bin/env bash
set -euo pipefail

PDF="build/main.pdf"
DVI="build/main.dvi"
SLUGS="build/slugs.txt"
OUTDIR="card"

# DVI needed for SVGs
latexmk -dvi

mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*

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

# --- Extract and convert PDFs ---
pages=("${!slugs[@]}")
IFS=$'\n' sorted_pages=($(sort -n <<<"${pages[*]}"))
minpage=${sorted_pages[0]}
maxpage=${sorted_pages[-1]}

for page in $(seq "$minpage" "$maxpage"); do
    slug="${slugs[$page]}"

    jpg_base="$OUTDIR/${slug}"
    pdftoppm -jpeg -jpegopt quality=95 -rx 400 -ry 400 -singlefile -f "$page" -l "$page" "$PDF" "$jpg_base"

    svg_file="$OUTDIR/${slug}.svg"
    dvisvgm --font-format=woff --bbox=papersize --page="$page" -o "$svg_file" "$DVI"
done

echo "All JPEGs and SVGs exported to $OUTDIR/"
