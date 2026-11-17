#!/bin/bash

# ------------ Init ------------ #

echo -e "\033[1;34m Removing auxiliary files \033[0m"
rm -rf _minted-* .minted-*
rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz
rm -f frontmatter/*.aux chapters/*.aux
rm -f _chapters_include.tex

START_TIME=$SECONDS
LOG_FILE="build.log"

CHAPTERS_DIR="chapters"
CHAPTERS_INCLUDE="_chapters_include.tex"

run_quiet() {
    local label="$1"
    shift
    echo -n "  $label ... "
    
    if ! "$@" > "$LOG_FILE" 2>&1; then
        echo -e "\033[1;31m[ÉCHEC]\033[0m"
        echo -e "\n\033[1;31m=== ERROR ===\033[0m\n"
        cat "$LOG_FILE"
        rm -f "$LOG_FILE"
        exit 1
    fi
    
    echo -e "\033[1;32m[OK]\033[0m"
}

shopt -s nocaseglob nullglob
set -e

# ------------ Inclusion automatique des Chapitres ------------ #

echo -e "\033[1;34m Scanning chapters directory \033[0m"

mkdir -p "$CHAPTERS_DIR"
> "$CHAPTERS_INCLUDE"

found_chapters=0
while IFS= read -r chap_path; do
    [ -n "$chap_path" ] || continue
    chap_no_ext="${chap_path%.tex}"
    echo "\\include{$chap_no_ext}" >> "$CHAPTERS_INCLUDE"
    found_chapters=$((found_chapters + 1))
done < <(find "$CHAPTERS_DIR" -maxdepth 1 -type f -name "*.tex" | sort)

echo "  $found_chapters chapters detected"
shopt -u nocaseglob nullglob

# ------------ Compilation LaTeX ------------ #

echo -e "\033[1;34m Compilation of LaTeX document \033[0m"
echo -e "\033[1;34m Generating .pdf \033[0m"

run_quiet "Generating LaTeX document" pdflatex -interaction=nonstopmode -halt-on-error --shell-escape main.tex

rm -f "$LOG_FILE" # Nettoyage fichier log

# ------------ Temps d'exécution ------------ #

ELAPSED=$(( SECONDS - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS_LEFT=$(( ELAPSED % 60 ))

if [ $MINUTES -gt 0 ]; then
    TIME_FORMAT="${MINUTES}m ${SECONDS_LEFT}s"
else
    TIME_FORMAT="${SECONDS_LEFT}s"  
fi

echo -e "\033[1;32m Compilation ended within $TIME_FORMAT \033[0m"