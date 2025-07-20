#!/usr/bin/env bash
set -euo pipefail

PDF="build/main.pdf"
SLUGS="build/slugs.txt"
OUTDIR="card"

mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*

# Parse slugs.txt into an associative array: page -> slug
declare -A slugs
while IFS=':' read -r page slug; do
    [[ -z "$slug" ]] && continue
    slugs[$page]=$slug
done < "$SLUGS"

# Determine the page range from slugs.txt
pages=("${!slugs[@]}")
IFS=$'\n' sorted_pages=($(sort -n <<<"${pages[*]}"))
minpage=${sorted_pages[0]}
maxpage=${sorted_pages[-1]}

# Split PDF pages (one per card)
pdfseparate -f "$minpage" -l "$maxpage" "$PDF" "$OUTDIR/card-%d.pdf"

# For each extracted PDF, rename and convert to JPEG and SVG
for page in $(seq "$minpage" "$maxpage"); do
    slug="${slugs[$page]}"
    pdf="$OUTDIR/card-$page.pdf"
    jpg_base="$OUTDIR/${slug}"
    svg_file="$OUTDIR/${slug}.svg"
    # Convert PDF to JPEG at good quality/resolution
    pdftoppm -jpeg -jpegopt quality=95 -rx 400 -ry 400 -singlefile "$pdf" "$jpg_base"
    # Convert PDF to SVG
    pdf2svg "$pdf" "$svg_file" 1
    rm "$pdf"  # Remove intermediate PDF
done

echo "All JPEGs and SVGs exported to $OUTDIR/"
