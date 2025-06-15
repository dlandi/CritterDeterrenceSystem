#!/usr/bin/env bash

set -euo pipefail

# This script:
# - Scans all .md files for PlantUML code blocks
# - For each .md, creates a diagrams/ subfolder in the same directory if needed
# - Renders each PlantUML block to a PNG in that folder
# - REPLACES each PlantUML block with an image link using a relative path based on diagram name

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
      
      # Skip all lines until closing ``` (consume the entire PlantUML block)
      i=$((i+1))
      while [[ $i -lt ${#lines[@]} && "${lines[$i]}" != '```' ]]; do
        i=$((i+1))
      done
      
      # Skip the closing ``` line too
      if [[ $i -lt ${#lines[@]} ]]; then
        i=$((i+1))
      fi

      # Extract diagram name from @startuml line if available, fallback to mdname-blocknum
      pumlfile="$diagrams_dir/tmp_plantuml_extract_${block_num}.puml"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      # Check if the next few lines already contain an image reference for this diagram
      # If so, skip adding another one
      next_lines=""
      for j in $(seq $i $((i+5))); do
        if [[ $j -lt ${#lines[@]} ]]; then
          next_lines+="${lines[$j]}"$'\n'
        fi
      done
      
      # Only add image if it doesn't already exist in the next few lines
      if [[ "$next_lines" != *"![${diagram_name}]"* && "$next_lines" != *"$imgpath"* ]]; then
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
        fi
        
        # REPLACE the PlantUML block with image reference
        updated_md+=""$'\n'"![${diagram_name}](${imgpath})"$'\n'
      else
        echo "Skipping duplicate image for $diagram_name - already exists"
        # Clean up temporary file
        rm -f "$pumlfile"
      fi
      
      # Continue to next iteration (don't increment i again)
      continue
    else
      # Skip existing standalone image references that match our pattern
      if [[ "$line" =~ ^\!\[.*\]\(diagrams\/.*\.png\)$ ]]; then
        echo "Removing existing duplicate image reference: $line"
        # Skip this line (don't add it to updated_md)
      else
        updated_md+="$line"$'\n'
      fi
    fi
    i=$((i+1))
  done

  # Write the updated markdown back to the file
  printf "%s" "$updated_md" > "$mdfile"
done

# Cleanup any temp files left (robustness)
find . -type f -name 'tmp_plantuml_extract_*.puml' -delete 2>/dev/null || true
find . -type f -name 'tmp_plantuml_extract_*.png' -delete 2>/dev/null || true