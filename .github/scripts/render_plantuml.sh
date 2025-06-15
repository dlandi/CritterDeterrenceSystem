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

  # Extract PlantUML blocks
  awk -v prefix="tmp_plantuml_extract_" -v lang="$PLANTUML_LANG" '
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
      i=$((i+1))
      pumlfile="tmp_plantuml_extract_${block_num}.puml"
      diagram_name=$(awk '/@startuml/ { gsub("@startuml", "", $0); gsub(/^[ \t]+|[ \t]+$/, "", $0); print $0; exit }' "$pumlfile" | tr -cd 'A-Za-z0-9_-')
      if [[ -z "$diagram_name" ]]; then
        diagram_name="${mdname}-${block_num}"
      fi
      imgname="${diagram_name}.png"
      imgpath="diagrams/${imgname}"

      if [[ -f "$pumlfile" ]]; then
        pushd "$out_mddir" >/dev/null
        docker run --rm -v "$PWD":"$PWD" -w "$PWD" plantuml/plantuml "../../../../../$pumlfile" -tpng -o diagrams
        popd >/dev/null
        mv "$out_mddir/diagrams/$pumlfile.png" "$diagrams_dir/$imgname" 2>/dev/null || \
        mv "$out_mddir/diagrams/tmp_plantuml_extract_${block_num}.png" "$diagrams_dir/$imgname" 2>/dev/null || true
        rm -f "$pumlfile"
        updated_md+="![${diagram_name}](${imgpath})"$'\n'
      fi
    else
      updated_md+="$line"$'\n'
      i=$((i+1))
    fi
  done

  mkdir -p "$out_mddir"
  printf "%s" "$updated_md" > "$out_mdfile"
  # Clean up any tmp puml/png in out_mddir/diagrams (for safety)
  rm -f "$out_mddir/diagrams/tmp_plantuml_extract_"*
  rm -f tmp_plantuml_extract_*
done