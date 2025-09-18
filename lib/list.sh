#!/bin/sh

list_chroots() {
  echo "List of chroot environments:"

  readonly headers="Name Path Type"

  if [ ! -f "$DB" ]; then
    echo "Error: Database file '$DB' not found." >&2
    return 1
  fi

  # Define variables
  rows="" col1_width=4 col2_width=4 col3_width=4

  # Read rows and update column widths
  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')

    # Update column widths for Name
    len=$(printf "%s" "$name" | wc -c)
    [ "$len" -gt "$col1_width" ] && col1_width=$len

    # Update column widths for Path
    len=$(printf "%s" "$path" | wc -c)
    [ "$len" -gt "$col2_width" ] && col2_width=$len

    # Update column widths for Type
    len=$(printf "%s" "$type" | wc -c)
    [ "$len" -gt "$col3_width" ] && col3_width=$len
  done <"$DB"

  # Print header
  printf "%-*s  %-*s  %-*s\n" "$col1_width" "Name" "$col2_width" "Path" "$col3_width" "Type"

  # Print separator line
  printf "%${col1_width}s  %${col2_width}s  %${col3_width}s\n" | tr ' ' '-'

  # Print rows
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -q '^#' && continue
    name=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')
    printf "%-*s  %-*s  %-*s\n" "$col1_width" "$name" "$col2_width" "$path" "$col3_width" "$type"
  done <"$DB"
}
