#!/bin/bash

# ------------ Init ------------ #

echo -e "\033[1;34m Removing auxiliary files \033[0m"
rm -rf _minted-* .minted-*
rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.synctex.gz
rm -f frontmatter/*.aux chapters/*.aux annexes/*.aux
rm -f _chapters_include.tex annexes.tex

START_TIME=$SECONDS
LOG_FILE="build.log"

CHAPTERS_DIR="chapters"
CHAPTERS_INCLUDE="_chapters_include.tex"
PDF_DIR="annexes/pdf"
SCRIPT_DIR="annexes/scripts"
TEX_DIR="annexes/tex"
OUTPUT_FILE="annexes.tex"

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

# ------------ Génération des Annexes ------------ #

echo -e "\033[1;34m Generating annexes.tex \033[0m"

{
    echo "\begin{subappendices}"
    echo ""
    echo "\phantomsection\hypertarget{annexes_toc}{}"
    echo "\chapter*{Liste of Annexes}"
    echo "\addcontentsline{toc}{chapter}{Liste of Annexes}"
    echo "\markboth{Liste of Annexes}{Liste of Annexes}"
    echo ""
    echo "\begin{itemize}[label=\textbullet]"

    i=1

    # Sommaire PDF
    if [ -d "$PDF_DIR" ]; then
        for pdf_path in "$PDF_DIR"/*.pdf; do
            [ -e "$pdf_path" ] || continue
            clean_name=$(basename "$pdf_path" .pdf | tr '_' ' ')
            echo "  \item \hyperlink{annexe:$i}{\textbf{Annexe n°$i :} $clean_name}"
            i=$((i + 1))
        done
    fi

    # Sommaire TeX
    if [ -d "$TEX_DIR" ]; then
        while IFS= read -r tex_path; do
            [ -e "$tex_path" ] || continue
            filename=$(basename "$tex_path")
            clean_name=$(basename "$tex_path" .tex | tr '_' ' ')
            filename_echape=$(echo "$filename" | sed 's/_/\\_/g')
            echo "  \item \hyperlink{annexe:$i}{\textbf{Annexe n°$i :} $clean_name}"
            i=$((i + 1))
        done < <(find "$TEX_DIR" -type f -name "*.tex" | sort)
    fi

    # Sommaire Scripts
    if [ -d "$SCRIPT_DIR" ]; then
        while IFS= read -r script_path; do
            [ -e "$script_path" ] || continue
            filename_echape=$(basename "$script_path" | sed 's/_/\\_/g')
            echo "  \item \hyperlink{annexe:$i}{\textbf{Annexe n°$i :} \texttt{$filename_echape}}"
            i=$((i + 1))
        done < <(find "$SCRIPT_DIR" -type f | sort)
    fi

    echo "\end{itemize}"
    echo "\newpage"
    echo ""

    i=1

    # PDF
    if [ -d "$PDF_DIR" ]; then
        for pdf_path in "$PDF_DIR"/*.pdf; do
            [ -e "$pdf_path" ] || continue
            clean_name=$(basename "$pdf_path" .pdf | tr '_' ' ')
            echo "\phantomsection\hypertarget{annexe:$i}{}"
            echo "\thispagestyle{empty}\vspace*{\fill}\begin{center}\Huge\textbf{Annexe n°$i}\\\\[0.5cm]\Large $clean_name\end{center}\vspace*{\fill}\newpage"
            echo "\includepdf[pages=-, scale=1, pagecommand={\thispagestyle{plain}}]{$pdf_path}"
            i=$((i + 1))
        done
    fi

    # Fichiers .tex
    if [ -d "$TEX_DIR" ]; then
        while IFS= read -r tex_path; do
            [ -e "$tex_path" ] || continue
            clean_name=$(basename "$tex_path" .tex | tr '_' ' ')
            echo "\phantomsection\hypertarget{annexe:$i}{}"
            echo "\thispagestyle{empty}\vspace*{\fill}\begin{center}\Huge\textbf{Annexe n°$i}\\\\[0.5cm]\Large $clean_name\end{center}\vspace*{\fill}\newpage\pagestyle{fancy}"
            echo "\input{$tex_path}\newpage"
            i=$((i + 1))
        done < <(find "$TEX_DIR" -type f -name "*.tex" | sort)
    fi

    # Scripts
    if [ -d "$SCRIPT_DIR" ]; then
        while IFS= read -r script_path; do
            [ -e "$script_path" ] || continue
            filename=$(basename "$script_path")
            ext="${filename##*.}"
            filename_echape=$(echo "$filename" | sed 's/_/\\_/g')

            langage="text"
            if [ "$ext" = "py" ]; then langage="python"; fi
            if [ "$ext" = "sh" ]; then langage="bash"; fi
            if [ "$ext" = "sql" ]; then langage="sql"; fi
            if [ "$ext" = "yaml" ] || [ "$ext" = "yml" ]; then langage="yaml"; fi

            echo "\phantomsection\hypertarget{annexe:$i}{}"
            echo "\thispagestyle{empty}\vspace*{\fill}\begin{center}\Huge\textbf{Annexe n°$i}\\\\[0.5cm]\Large \texttt{$filename_echape}\end{center}\vspace*{\fill}\clearpage\pagestyle{fancy}"
            echo "\inputminted[linenos=true, frame=lines, framesep=2mm, fontsize=\footnotesize, breaklines=true]{$langage}{$script_path}\newpage"
            i=$((i + 1))
        done < <(find "$SCRIPT_DIR" -type f | sort)
    fi

    echo "\end{subappendices}"
} > "$OUTPUT_FILE"

shopt -u nocaseglob nullglob

# ------------ Compilation LaTeX ------------ #

echo -e "\033[1;34m Compilation of LaTeX document \033[0m"
echo -e "\033[1;34m Generating .pdf \033[0m"

run_quiet "Generating LaTeX document" pdflatex -interaction=nonstopmode -halt-on-error --shell-escape main.tex

# Nettoyage fichier log
rm -f "$LOG_FILE"

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