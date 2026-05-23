#!/bin/sh

list_saved() {
  echo "List of saved chroot environments:"

  # Define variables
  local rows="" col1_width=4 col2_width=4

  # Read rows and update column widths
  for file in $CHROOT_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue

    local name=$(basename "$file")
    local size=$(du -sh "$file" | awk '{print $1}')

    # Update column widths for Name
    local len=$(printf "%s" "$name" | wc -c)
    [ "$len" -gt "$col1_width" ] && col1_width=$len

    # Update column widths for Size
    len=$(printf "%s" "$size" | wc -c)
    [ "$len" -gt "$col2_width" ] && col2_width=$len
  done
  unset file

  # Print header
  printf "%-*s  %-*s\n" "$col1_width" "Name" "$col2_width" "Size"

  # Print separator line
  printf "%${col1_width}s  %${col2_width}s\n" | tr ' ' '-'

  # Print rows
  for file in $CHROOT_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue

    local name=$(basename "$file")
    local size=$(du -sh "$file" | awk '{print $1}')
    printf "%-*s  %-*s\n" "$col1_width" "$name" "$col2_width" "$size"
  done
  unset file
}

remove_saved() {
  source "$LIB/utils/colors.sh"

  if [ -z "${1:-}" ]; then
    error "Missing saved chroot name"
    show_help_saved
    exit 1
  fi

  local saved_name="$1"
  local saved_file="$CHROOT_CACHE_DIR/${saved_name}.tar.gz"

  if [ ! -f "$saved_file" ]; then
    error "Saved chroot '$saved_name' not found at $saved_file"
    exit 1
  fi

  info "Removing saved chroot $saved_name"
  rm -f "$saved_file"
  success "Saved chroot $saved_name removed successfully."
}

show_help_saved() {
  source "$LIB/utils/colors.sh"
  printf '%b\n' "${BOLD}${BLUE}Chrootctl saved v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME saved [subcommand] [options]"
  printf '%b\n' "${BOLD}${CYAN}Subcommands:${NC}"
  printf '%b\n' "  ${GREEN}list${NC}              List all saved chroot environments (default)"
  printf '%b\n' "  ${GREEN}remove${NC} <name>     Remove a saved chroot environment"
  printf '%b\n' "  ${GREEN}-h, --help${NC}       Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME saved${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME saved list${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME saved remove my-chroot${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}

saved_cmd() {
  case "${1:-list}" in
  list)
    list_saved
    ;;
  remove)
    shift || true
    remove_saved "$@"
    ;;
  -h | --help)
    show_help_saved
    exit 0
    ;;
  *)
    error "Unknown subcommand: $1"
    show_help_saved
    exit 1
    ;;
  esac
}
