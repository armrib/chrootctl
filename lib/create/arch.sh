#!/bin/sh

create_arch() {
  if [ -n "${1:-}" ]; then
    readonly chroot_path="$1"
    shift
  else
    echo "Missing chroot path"
    show_help_create_arch
    exit 1
  fi

  local url="https://raw.github.com/tokland/arch-bootstrap/master/arch-bootstrap.sh"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -h | --help)
      show_help_create_arch
      exit 0
      ;;
    *)
      if [ -n "${1:-}" ]; then
        echo "Unknown option ($1)"
        show_help_create_arch
        exit 1
      else
        shift
      fi
      ;;
    esac
  done

  # Download the file if it doesn't exist
  if [ ! -f "$DIST_CACHE_DIR/arch.sh" ]; then
    echo "Downloading $url"
    wget "$url" -O "$DIST_CACHE_DIR/arch-bootstrap.sh"
    apk add bash zstd curl
    bash "$DIST_CACHE_DIR/arch-bootstrap.sh" "$chroot_path"
    tar --no-same-owner --no-same-permissions -xzf "$DIST_CACHE_DIR/arch.tar.gz" -C "$chroot_path"
  else
    # Extract the file
    tar --no-same-owner --no-same-permissions -xzf "$DIST_CACHE_DIR/arch.tar.gz" -C "$chroot_path"
  fi
}

show_help_create_arch() {
  source "$LIB/utils/colors.sh"
  printf '%b\n' "${BOLD}${BLUE}Chrootctl v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME create $(basename $chroot_path) -t arch [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}-h, --help${NC}       Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test -t arch${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test -t arch -d /var/lib/chrootctl/test${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
