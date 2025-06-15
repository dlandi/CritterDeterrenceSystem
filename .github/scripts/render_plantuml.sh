#!/usr/bin/env bash

set -euo pipefail

PLANTUML_LANG="plantuml"

find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true

find . -type f -name "*.md" | while read -r mdfile; do
  mddir="$(dirname "$mdfile")"
  mdname="$(basename "${mdfile%.*}")"
  diagrams_dir="$mddir/diagrams"
  mkdir -p "$diagrams_dir"

  mapfile -t lines < "$mdfile"
  updated_md=""
  i=0
  block_num=0

  while [[ $i -lt ${#lines[@]} ]]; do
    line="${lines[$i]}"
    # Detect start of PlantUML code block
    if [[ "$line" == \`\`\`"$PLANTUML_LANG"* ]]; then
      block_num=$((block_num+1))
      # Gather the PlantUML block for rendering
      code_block=()
      i=$((i+1))
      while [[ $i -lt ${#lines[@]} && "${lines[$i]}" != '```' ]]; do
        code_block+=("${lines[$i]}")
        i=$((i+1))
      done
      # Skip closing ```
      i=$((i+1))

      # Write temp .puml for docker rendering
      pumlfile="$diagrams_dir/tmp_plantuml_extract_${block_num}.puml"
      printf "%s\n" "${code_block[@]}" > "$pumlfile"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      # Render the diagram
      abs_diagrams_dir="$(realpath "$diagrams_dir")"
      abs_pumlfile="$(realpath "$pumlfile")"
      parent_dir="$(dirname "$abs_diagrams_dir")"
      rel_pumlfile="diagrams/$(basename "$pumlfile")"
      docker run --rm -v "$parent_dir":"$parent_dir" -w "$parent_dir" plantuml/plantuml "$rel_pumlfile" -tpng

      generated_png="$diagrams_dir/tmp_plantuml_extract_${block_num}.png"
      target_png="$diagrams_dir/$imgname"
      if [[ -f "$generated_png" ]]; then
        mv "$generated_png" "$target_png"
      fi
      rm -f "$pumlfile"

      # Check for existing image reference directly after this block (skip blank lines)
      skip_image_reference=false
      for j in {0..2}; do
        next_line_idx=$((i+j))
        if [[ $next_line_idx -lt ${#lines[@]} ]]; then
          next_line="${lines[$next_line_idx]}"
          if [[ "$next_line" =~ ^\!\[.*\]\($imgpath\)$ ]]; then
            skip_image_reference=true
            i=$((next_line_idx+1)) # skip the duplicate image line as well
            break
          fi
          # Skip blank lines
          if [[ ! "$next_line" =~ [^[:space:]] ]]; then
            continue
          fi
        fi
      done

      # Insert image reference if not found
      if ! $skip_image_reference; then
        updated_md+=$'\n'"![${diagram_name}](${imgpath})"$'\n'
      fi

    else
      # Remove duplicate image lines anywhere else in the file
      if [[ "$line" =~ ^\!\[.*\]\(diagrams\/.*\.png\)$ ]]; then
        continue
      fi
      updated_md+="$line"$'\n'
      i=$((i+1))
    fi
  done

  printf "%s" "$updated_md" > "$mdfile"
done

find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true
find . -type f -name 'tmp_plantuml_extract_*.png' -delete 2>/dev/null || true