#!/bin/bash
set -euo pipefail

# --- Settings ---
GITREF="${1:-printed}"
TEXFILE="main.tex"
PDF="main.pdf"
TMPDIR=$(mktemp -d)
OLDDIR="$TMPDIR/old"
PDF1="$TMPDIR/old_main.pdf"
PDF2="$(pwd)/build/main.pdf"
CHANGED_PAGES=""

# --- Build old version ---
echo "Checking out $GITREF and building in $OLDDIR..."
git worktree add --detach "$OLDDIR" "$GITREF"
pushd "$OLDDIR" >/dev/null
latexmk -pdf -quiet "$TEXFILE"
popd >/dev/null
cp "$OLDDIR/build/main.pdf" "$TMPDIR/old_main.pdf"
git worktree remove "$OLDDIR"

# --- Ensure current version is built ---
if [ ! -f "$PDF2" ]; then
    echo "Building current main.pdf..."
    latexmk -pdf -quiet "$TEXFILE"
fi

# --- Render both PDFs to images ---
echo "Rendering pages to images for comparison..."
mkdir "$TMPDIR/pdf1" "$TMPDIR/pdf2"
gs -q -dNOPAUSE -r144 -sDEVICE=png16m -dBATCH -sOutputFile="$TMPDIR/pdf1/page-%03d.png" "$PDF1"
gs -q -dNOPAUSE -r144 -sDEVICE=png16m -dBATCH -sOutputFile="$TMPDIR/pdf2/page-%03d.png" "$PDF2"

# --- Compare images page-by-page ---
echo "Comparing rendered pages..."
CHANGED_PAGES_LIST=()
for img in "$TMPDIR"/pdf1/*.png; do
    base=$(basename "$img")
    page=${base#page-}
    page=${page%.png}
    if [ -f "$TMPDIR/pdf2/$base" ]; then
        if ! cmp -s "$TMPDIR/pdf1/$base" "$TMPDIR/pdf2/$base"; then
            # Remove leading zeros from page for qpdf compatibility
            page_num=$((10#$page))
            CHANGED_PAGES_LIST+=("$page_num")
            echo "Page $page_num differs"
        fi
    fi
done

if [ "${#CHANGED_PAGES_LIST[@]}" -eq 0 ]; then
    echo "No changed pages detected!"
    rm -rf "$TMPDIR"
    exit 0
fi

# Create a comma-separated list (e.g. 4,7,11)
CHANGED_PAGES=$(IFS=, ; echo "${CHANGED_PAGES_LIST[*]}")

# --- Extract changed pages from current PDF ---
OUTCHANGED="changed-pages.pdf"
if command -v qpdf &>/dev/null; then
    qpdf "$PDF2" --pages . $CHANGED_PAGES -- "$OUTCHANGED"
    echo "Created $OUTCHANGED with just changed pages."
elif command -v pdftk &>/dev/null; then
    pdftk "$PDF2" cat $CHANGED_PAGES output "$OUTCHANGED"
    echo "Created $OUTCHANGED with just changed pages."
else
    echo "Install qpdf or pdftk to extract changed pages automatically."
    exit 1
fi

# --- Clean up ---
rm -rf "$TMPDIR"
