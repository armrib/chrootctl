#!/bin/sh

source "$LIB/utils/colors.sh"

list_chroots() {
  header "List of chroot environments:"

  if [ ! -f "$DB" ]; then
    error "Database file '$DB' not found."
    return 1
  fi

  # Define variables
  local rows="" col1_width=4 col2_width=4 col3_width=4 col4_width=7 col5_width=7 col6_width=4 col7_width=5 col8_width=12 col9_width=13 col10_width=8 col11_width=8

  # Read rows and update column widths
  while IFS= read -r line; do
    local name=$(echo "$line" | awk '{print $1}')
    local dir=$(echo "$line" | awk '{print $2}')
    local type=$(echo "$line" | awk '{print $3}')
    local shell=$(echo "$line" | awk '{print $4}')
    local mount_private=$(echo "$line" | awk '{print $5}')
    local mount_shared=$(echo "$line" | awk '{print $6}')
    local bind_ro=$(echo "$line" | awk '{print $7}')
    local bind_rw=$(echo "$line" | awk '{print $8}')
    local user=$(echo "$line" | awk '{print $9}')
    local version=$(echo "$line" | awk '{print $10}')
    local arch=$(echo "$line" | awk '{print $11}')

    # Update column widths for Name
    local len=$(printf "%s" "$name" | wc -c)
    [ "$len" -gt "$col1_width" ] && col1_width=$len

    # Update column widths for Path
    len=$(printf "%s" "$dir" | wc -c)
    [ "$len" -gt "$col2_width" ] && col2_width=$len

    # Update column widths for Type
    len=$(printf "%s" "$type" | wc -c)
    [ "$len" -gt "$col3_width" ] && col3_width=$len

    # Update column widths for User
    len=$(printf "%s" "$user" | wc -c)
    [ "$len" -gt "$col4_width" ] && col4_width=$len

    # Update column widths for Version
    len=$(printf "%s" "$version" | wc -c)
    [ "$len" -gt "$col5_width" ] && col5_width=$len

    # Update column widths for Arch
    len=$(printf "%s" "$arch" | wc -c)
    [ "$len" -gt "$col6_width" ] && col6_width=$len

    # Update column widths for Shell
    len=$(printf "%s" "$shell" | wc -c)
    [ "$len" -gt "$col7_width" ] && col7_width=$len

    # Update column widths for Mount Private
    len=$(printf "%s" "$mount_private" | wc -c)
    [ "$len" -gt "$col8_width" ] && col8_width=$len

    # Update column widths for Mount Shared
    len=$(printf "%s" "$mount_shared" | wc -c)
    [ "$len" -gt "$col9_width" ] && col9_width=$len

    # Update column widths for Bind RO (cap at 30)
    len=$(printf "%s" "$bind_ro" | wc -c)
    [ "$len" -gt "$col10_width" ] && col10_width=$len
    [ "$col10_width" -gt 30 ] && col10_width=30

    # Update column widths for Bind RW (cap at 30)
    len=$(printf "%s" "$bind_rw" | wc -c)
    [ "$len" -gt "$col11_width" ] && col11_width=$len
    [ "$col11_width" -gt 30 ] && col11_width=30
  done <"$DB"
  unset line

  # Print header
  local sep="$BOLD$CYAN"
  printf "%b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b | %b%-*s%b\n" \
    "$sep" "$col1_width" "Name" "$NC" \
    "$sep" "$col2_width" "Path" "$NC" \
    "$sep" "$col3_width" "Type" "$NC" \
    "$sep" "$col4_width" "User" "$NC" \
    "$sep" "$col5_width" "Version" "$NC" \
    "$sep" "$col6_width" "Arch" "$NC" \
    "$sep" "$col7_width" "Shell" "$NC" \
    "$sep" "$col8_width" "Mount Private" "$NC" \
    "$sep" "$col9_width" "Mount Shared" "$NC" \
    "$sep" "$col10_width" "Bind RO" "$NC" \
    "$sep" "$col11_width" "Bind RW" "$NC"

  # Print separator line
  printf "%${col1_width}s-+-%-${col2_width}s-+-%-${col3_width}s-+-%-${col4_width}s-+-%-${col5_width}s-+-%-${col6_width}s-+-%-${col7_width}s-+-%-${col8_width}s-+-%-${col9_width}s-+-%-${col10_width}s-+-%-${col11_width}s\n" | tr ' ' '-'

  # Print rows
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -q '^#' && continue
    local raw_ro=$(echo "$line" | awk '{print $7}')
    local raw_rw=$(echo "$line" | awk '{print $8}')
    local bind_ro=$([ "$raw_ro" = "none" ] && echo "none" || echo "$raw_ro" | awk -F, '{for(i=1;i<=NF;i++){split($i,a,":");gsub(".*/","",a[2]);printf "%s%s",a[2],(i<NF?",":"")} print ""}')
    local bind_rw=$([ "$raw_rw" = "none" ] && echo "none" || echo "$raw_rw" | awk -F, '{for(i=1;i<=NF;i++){split($i,a,":");gsub(".*/","",a[2]);printf "%s%s",a[2],(i<NF?",":"")} print ""}')
    printf "%-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s | %-*s\n" \
      "$col1_width" "$(echo "$line" | awk '{print $1}')" \
      "$col2_width" "$(echo "$line" | awk '{print $2}')" \
      "$col3_width" "$(echo "$line" | awk '{print $3}')" \
      "$col4_width" "$(echo "$line" | awk '{print $9}')" \
      "$col5_width" "$(echo "$line" | awk '{print $10}')" \
      "$col6_width" "$(echo "$line" | awk '{print $11}')" \
      "$col7_width" "$(echo "$line" | awk '{print $4}')" \
      "$col8_width" "$(echo "$line" | awk '{print $5}')" \
      "$col9_width" "$(echo "$line" | awk '{print $6}')" \
      "$col10_width" "$bind_ro" \
      "$col11_width" "$bind_rw"
  done <"$DB"
  unset line
}
