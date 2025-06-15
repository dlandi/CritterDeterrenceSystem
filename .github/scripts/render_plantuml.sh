#!/usr/bin/env bash

set -euo pipefail

PLANTUML_LANG="plantuml"
INDIR="documentation/InDevelopment"
OUTDIR="documentation/Published"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

find "$INDIR" -type f -name "*.md" | while read -r mdfile; do
  relpath="${mdfile#$INDIR/}"
  out_mdfile="$OUTDIR/$relpath"
  out_mddir="$(dirname "$out_mdfile")"
  mdname="$(basename "${mdfile%.*}")"
  diagrams_dir="$out_mddir/diagrams"
  mkdir -p "$diagrams_dir"

  updated_md=""
  block_num=0
  mapfile -t lines < "$mdfile"

  i=0
  while [[ $i -lt ${#lines[@]} ]]; do
    line="${lines[$i]}"
    if [[ "$line" == \`\`\`"$PLANTUML_LANG"* ]]; then
      block_num=$((block_num+1))
      block_lines=()
      i=$((i+1))
      while [[ $i -lt ${#lines[@]} && "${lines[$i]}" != '```' ]]; do
        block_lines+=("${lines[$i]}")
        i=$((i+1))
      done
      i=$((i+1))

      # Write .puml file INSIDE diagrams_dir, so all relative paths work
      pumlfile_rel="diagrams/tmp_plantuml_extract_${block_num}.puml"
      pumlfile_abs="$diagrams_dir/tmp_plantuml_extract_${block_num}.puml"
      printf "%s\n" "${block_lines[@]}" > "$pumlfile_abs"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile_abs" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      # Run PlantUML from the output .md's directory, input/output to diagrams/
      pushd "$out_mddir" >/dev/null
      docker run --rm -v "$PWD":"$PWD" -w "$PWD" plantuml/plantuml "$pumlfile_rel" -tpng
      if [[ -f "$pumlfile_rel.png" ]]; then
        mv "$pumlfile_rel.png" "$imgpath"
      elif [[ -f "diagrams/tmp_plantuml_extract_${block_num}.png" ]]; then
        mv "diagrams/tmp_plantuml_extract_${block_num}.png" "$imgpath"
      fi
      rm -f "$pumlfile_rel"
      popd >/dev/null

      updated_md+="![${diagram_name}](${imgpath})"$'\n'
    else
      updated_md+="$line"$'\n'
      i=$((i+1))
    fi
  done

  mkdir -p "$out_mddir"
  printf "%s" "$updated_md" > "$out_mdfile"
done