#!/bin/bash
set -euo pipefail

TEXFILE="main.tex"
PDF="build/main.pdf"
OUTPDF="print.pdf"

# --- Sanity checks ---
if [ -n "$(git status --porcelain)" ]; then
    echo "ERROR: Your git tree is dirty. Commit or stash changes before printing."
    exit 1
fi

if [ -f "$OUTPDF" ]; then
    echo "ERROR: $OUTPDF already exists. Please move or remove it before continuing."
    exit 1
fi

GITREF="printed"
TMPDIR=$(mktemp -d)
OLDDIR="$TMPDIR/old"

# --- Build old version ---
echo "Checking out $GITREF and building in $OLDDIR..."
git worktree add --detach "$OLDDIR" "$GITREF"
pushd "$OLDDIR" >/dev/null
latexmk -quiet "$TEXFILE"
popd >/dev/null

cp "$OLDDIR/build/main.pdf" "$TMPDIR/old_main.pdf"
cp "$OLDDIR/build/main.toc" "$TMPDIR/old_main.toc"
git worktree remove "$OLDDIR"
PDF1="$TMPDIR/old_main.pdf"
TOC1="$TMPDIR/old_main.toc"
PDF2="$(pwd)/build/main.pdf"
TOC2="$(pwd)/build/main.toc"

# --- Ensure current version is built ---
if [ ! -f "$PDF2" ]; then
    echo "Building current main.pdf..."
    latexmk -pdf "$TEXFILE"
fi

# --- Parse ToC for subsections (cards) ---
awk -F '[{}]' '/contentsline {subsection}/ {print $4 "|" $6}' "$TOC1" > "$TMPDIR/toc_old.txt"
awk -F '[{}]' '/contentsline {subsection}/ {print $4 "|" $6}' "$TOC2" > "$TMPDIR/toc_new.txt"

normalize_title() {
    # Lowercase, remove all non-a-z
    tr '[:upper:]' '[:lower:]' | tr -cd 'a-z'
}

# --- Compare by card title, not page ---
echo "Finding changed or new cards..."
CHANGED_PAGES_LIST=()
while IFS='|' read -r title newpage; do
    norm_title=$(echo "$title" | normalize_title)
    oldpage=$(awk -F'|' -v nt="$norm_title" '
        {
            # Normalize old title
            norm = tolower($1)
            gsub(/[^a-z]/, "", norm)
            if (norm == nt) print $2
        }' "$TMPDIR/toc_old.txt")
    if [ -z "$oldpage" ]; then
        echo "NEW: $title (page $newpage)"
        CHANGED_PAGES_LIST+=("$newpage")
    else
        pdftotext -f "$oldpage" -l "$oldpage" "$PDF1" "$TMPDIR/old.txt"
        pdftotext -f "$newpage" -l "$newpage" "$PDF2" "$TMPDIR/new.txt"
        if ! cmp -s "$TMPDIR/old.txt" "$TMPDIR/new.txt"; then
            echo "CHANGED: $title (page $newpage)"
            CHANGED_PAGES_LIST+=("$newpage")
        fi
        rm -f "$TMPDIR/old.txt" "$TMPDIR/new.txt"
    fi
done < "$TMPDIR/toc_new.txt"

if [ "${#CHANGED_PAGES_LIST[@]}" -eq 0 ]; then
    echo "No changed or new cards detected!"
    rm -rf "$TMPDIR"
    exit 0
fi

CHANGED_PAGES=$(IFS=, ; echo "${CHANGED_PAGES_LIST[*]}")

# --- Extract changed pages from current PDF ---
if command -v qpdf &>/dev/null; then
    qpdf "$PDF2" --pages . $CHANGED_PAGES -- "$OUTPDF"
    echo "Created $OUTPDF with just changed/new cards."
elif command -v pdftk &>/dev/null; then
    pdftk "$PDF2" cat $CHANGED_PAGES output "$OUTPDF"
    echo "Created $OUTPDF with just changed/new cards."
else
    echo "Install qpdf or pdftk to extract changed pages automatically."
    exit 1
fi

# --- Confirm before updating printed tag ---
echo
read -rp "Did you print and verify $OUTPDF successfully? Move 'printed' tag to current commit? [y/N] " CONFIRM
case "$CONFIRM" in
    [yY][eE][sS]|[yY])
        echo "Updating 'printed' tag to current commit."
        git tag -f -a printed -m "Printed on $(date +%Y-%m-%d)"
        ;;
    *)
        echo "Leaving 'printed' tag unchanged."
        ;;
esac

rm -rf "$TMPDIR"
