#!/usr/bin/env bash

set -euo pipefail

# This script:
# - Scans all .md files for PlantUML code blocks
# - For each .md, creates a diagrams/ subfolder in the same directory if needed
# - Renders each PlantUML block to a PNG in that folder
# - Inserts or replaces an image link after each PlantUML block using a relative path based on diagram name

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
    # Check for PlantUML code block start
    if [[ "$line" == \`\`\`"$PLANTUML_LANG"* ]]; then
      block_num=$((block_num+1))
      block_lines=()
      block_lines+=("$line")
      i=$((i+1))
      
      # Collect all lines until closing ```
      while [[ $i -lt ${#lines[@]} && "${lines[$i]}" != '```' ]]; do
        block_lines+=("${lines[$i]}")
        i=$((i+1))
      done
      
      # Add the closing ``` line
      if [[ $i -lt ${#lines[@]} ]]; then
        block_lines+=("${lines[$i]}")
      fi

      # Add the PlantUML block to output
      for block_line in "${block_lines[@]}"; do
        updated_md+="$block_line"$'\n'
      done

      # Extract diagram name from @startuml line if available, fallback to mdname-blocknum
      pumlfile="$diagrams_dir/tmp_plantuml_extract_${block_num}.puml"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      if [[ -f "$pumlfile" ]]; then
        # Get absolute path for Docker volume mounting
        abs_diagrams_dir="$(realpath "$diagrams_dir")"
        abs_pumlfile="$(realpath "$pumlfile")"
        
        # Render PlantUML diagram using Docker with absolute paths
        # Use the parent directory of diagrams as working directory
        parent_dir="$(dirname "$abs_diagrams_dir")"
        rel_pumlfile="diagrams/$(basename "$pumlfile")"
        
        echo "Rendering PlantUML: $pumlfile -> $diagrams_dir/$imgname"
        docker run --rm \
          -v "$parent_dir":"$parent_dir" \
          -w "$parent_dir" \
          plantuml/plantuml \
          "$rel_pumlfile" \
          -tpng
        
        # The output should be generated as tmp_plantuml_extract_X.png in diagrams dir
        generated_png="$diagrams_dir/tmp_plantuml_extract_${block_num}.png"
        target_png="$diagrams_dir/$imgname"
        
        if [[ -f "$generated_png" ]]; then
          # Rename to the desired name
          mv "$generated_png" "$target_png"
          echo "Generated: $target_png"
        elif [[ -f "$diagrams_dir/${diagram_name}.png" ]]; then
          # File already has correct name from @startuml directive
          echo "Generated: $diagrams_dir/${diagram_name}.png"
        else
          echo "Warning: Expected PNG file not found after PlantUML generation"
          ls -la "$diagrams_dir"
        fi
        
        # Clean up temporary file
        rm -f "$pumlfile"
        
        # Add image reference after the PlantUML block
        updated_md+=""$'\n'"![${diagram_name}](${imgpath})"$'\n'
      fi
    else
      updated_md+="$line"$'\n'
    fi
    i=$((i+1))
  done

  # Write the updated markdown back to the file
  printf "%s" "$updated_md" > "$mdfile"
done

# Cleanup any temp files left (robustness)
find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true
find . -type f -name 'tmp_plantuml_extract_*.png' -delete 2>/dev/null || true