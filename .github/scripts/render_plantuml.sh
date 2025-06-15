#!/usr/bin/env bash

set -euo pipefail

PLANTUML_LANG="plantuml"

# Cleanup any temporary files from previous runs
find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true

find . -type f -name "*.md" | while read -r mdfile; do
  mddir="$(dirname "$mdfile")"
  mdname="$(basename "${mdfile%.*}")"
  diagrams_dir="$mddir/diagrams"
  mkdir -p "$diagrams_dir"

  # Extract all PlantUML blocks to temp files, number them
  awk -v prefix="$diagrams_dir/tmp_plantuml_extract_" -v lang="$PLANTUML_LANG" '
    BEGIN { n=0; inside=0 }
    {
      if ($0 ~ "```"lang) { inside=1; n++; next }
      if (inside && $0 ~ /^```/) { inside=0; next }
      if (inside) print $0 > (prefix n ".puml")
    }
  ' "$mdfile"

  updated_md=""
  block_num=0

  mapfile -t lines < "$mdfile"

  i=0
  while [[ $i -lt ${#lines[@]} ]]; do
    line="${lines[$i]}"
    if [[ "$line" == \`\`\`"$PLANTUML_LANG"* ]]; then
      block_num=$((block_num+1))
      block_lines=()
      block_lines+=("$line")
      i=$((i+1))
      while [[ $i -lt ${#lines[@]} && "${lines[$i]}" != '```' ]]; do
        block_lines+=("${lines[$i]}")
        i=$((i+1))
      done
      # Skip the closing ```
      i=$((i+1))
      # Extract diagram name from @startuml line if available, fallback to mdname-blocknum
      pumlfile="$diagrams_dir/tmp_plantuml_extract_${block_num}.puml"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      if [[ -f "$pumlfile" ]]; then
        docker run --rm -v "$PWD":"$PWD" -w "$PWD" plantuml/plantuml "$pumlfile" -tpng -o "$diagrams_dir"
        # Rename if the output name is different than expected
        if [[ -f "$diagrams_dir/${diagram_name}.png" ]]; then
          :
        elif [[ -f "$diagrams_dir/tmp_plantuml_extract_${block_num}.png" ]]; then
          mv -f "$diagrams_dir/tmp_plantuml_extract_${block_num}.png" "$diagrams_dir/$imgname"
        fi
        rm -f "$pumlfile"
        updated_md+="![${diagram_name}](${imgpath})"$'\n'
      fi
    else
      updated_md+="$line"$'\n'
      i=$((i+1))
    fi
  done

  printf "%s" "$updated_md" > "$mdfile"
done

# Cleanup any temp files left (robustness)
find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true
find . -type f -name 'tmp_plantuml_extract_*.png' -delete 2>/dev/null || true
