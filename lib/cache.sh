#!/bin/sh

list_cache() {
  echo "List of cached distributions:"

  # Define variables
  local rows="" col1_width=4 col2_width=4

  # Read rows and update column widths
  for file in $DIST_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue

    local name=$(basename "$file")
    local size=$(du -sh "$file" | awk '{print $1}')

    # Update column widths for Name
    local len=$(printf "%s" "$name" | wc -c)
    [ "$len" -gt "$col1_width" ] && col1_width=$len

    # Update column widths for Path
    len=$(printf "%s" "$size" | wc -c)
    [ "$len" -gt "$col2_width" ] && col2_width=$len
  done
  unset file

  # Print header
  printf "%-*s  %-*s  %-*s  %-*s\n" "$col1_width" "Name" "$col2_width" "Size"

  # Print separator line
  printf "%${col1_width}s  %${col2_width}s\n" | tr ' ' '-'

  # Print rows
  for file in $DIST_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue

    local name=$(basename "$file")
    local size=$(du -sh "$file" | awk '{print $1}')
    printf "%-*s  %-*s  %-*s  %-*s\n" "$col1_width" "$name" "$col2_width" "$size"
  done
  unset file
}
