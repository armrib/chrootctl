#!/bin/sh

list_chroots() {
  echo "List of chroot environments:"

  if [ ! -f "$DB" ]; then
    echo "Error: Database file '$DB' not found." >&2
    return 1
  fi

  # Define variables
  local rows="" col1_width=4 col2_width=4 col3_width=4 col4_width=5 col5_width=12 col6_width=13

  # Read rows and update column widths
  while IFS= read -r line; do
    local name=$(echo "$line" | awk '{print $1}')
    local dir=$(echo "$line" | awk '{print $2}')
    local type=$(echo "$line" | awk '{print $3}')
    local shell=$(echo "$line" | awk '{print $4}')
    local mount_private=$(echo "$line" | awk '{print $5}')
    local mount_shared=$(echo "$line" | awk '{print $6}')

    # Update column widths for Name
    local len=$(printf "%s" "$name" | wc -c)
    [ "$len" -gt "$col1_width" ] && col1_width=$len

    # Update column widths for Path
    len=$(printf "%s" "$dir" | wc -c)
    [ "$len" -gt "$col2_width" ] && col2_width=$len

    # Update column widths for Type
    len=$(printf "%s" "$type" | wc -c)
    [ "$len" -gt "$col3_width" ] && col3_width=$len

    # Update column widths for Shell
    len=$(printf "%s" "$shell" | wc -c)
    [ "$len" -gt "$col4_width" ] && col4_width=$len

    # Update column widths for Mount RO
    len=$(printf "%s" "$mount_private" | wc -c)
    [ "$len" -gt "$col5_width" ] && col5_width=$len

    # Update column widths for Mount RW
    len=$(printf "%s" "$mount_shared" | wc -c)
    [ "$len" -gt "$col6_width" ] && col6_width=$len
  done <"$DB"
  unset line

  # Print header
  printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n" "$col1_width" "Name" "$col2_width" "Path" "$col3_width" "Type" "$col4_width" "Shell" "$col5_width" "Mount Private" "$col6_width" "Mount Shared"

  # Print separator line
  printf "%${col1_width}s  %${col2_width}s  %${col3_width}s  %${col4_width}s  %${col5_width}s  %${col6_width}s\n" | tr ' ' '-'

  # Print rows
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -q '^#' && continue
    local name=$(echo "$line" | awk '{print $1}')
    local dir=$(echo "$line" | awk '{print $2}')
    local type=$(echo "$line" | awk '{print $3}')
    local shell=$(echo "$line" | awk '{print $4}')
    local mount_private=$(echo "$line" | awk '{print $5}')
    local mount_shared=$(echo "$line" | awk '{print $6}')
    printf "%-*s  %-*s  %-*s  %-*s  %-*s  %-*s\n" "$col1_width" "$name" "$col2_width" "$dir" "$col3_width" "$type" "$col4_width" "$shell" "$col5_width" "$mount_private" "$col6_width" "$mount_shared"
  done <"$DB"
  unset line
}
