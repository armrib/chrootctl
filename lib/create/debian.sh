#!/bin/sh

create_debian() {
  if [ -n "${1:-}" ]; then
    readonly chroot_path=$1
    shift
  else
    echo "Missing chroot path"
    show_help_create_debian
    exit 1
  fi

  local suite="stable"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -s | --suite)
      suite="$2"
      shift 2
      ;;
    -h | --help)
      show_help_create_debian
      exit 0
      ;;
    *)
      if [ -n "${1:-}" ]; then
        echo "Unknown option ($1)"
        show_help_create_debian
        exit 1
      else
        shift
      fi
      ;;
    esac
  done

  if [ -f "$DIST_CACHE_DIR/debian-${suite}.tar.gz" ]; then
    echo "Using existing Debian chroot tarball"
    tar -xzf "$DIST_CACHE_DIR/debian-${suite}.tar.gz" -C "$chroot_path"
  else
    echo "Creating Debian chroot from debootstrap"
    if ! apk add debootstrap perl; then
      echo "Failed to install debootstrap or perl"
      exit 1
    fi
    if ! debootstrap "$suite" "$chroot_path" http://deb.debian.org/debian/; then
      echo "Failed to create Debian chroot"
      exit 1
    fi
    echo "Removing debootstrap and perl"
    apk del debootstrap perl
    echo "Compressing clean chroot for faster creation"
    (cd "$chroot_path" && tar -czf "$DIST_CACHE_DIR/debian-${suite}.tar.gz" .)
  fi
}

show_help_create_debian() {
  source "$LIB/utils/colors.sh"
  printf '%b\n' "${BOLD}${BLUE}Chrootctl v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME create $(basename $chroot_path) -t debian [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}-s, --suite${NC} <suite> Debian suite to use (stable, testing, ...) (default: stable)"
  printf '%b\n' "  ${GREEN}-d, --dir${NC}   <path>  Path to the chroot environment (default: /tmp)"
  printf '%b\n' "  ${GREEN}-h, --help${NC}          Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test -d /tmp/chroot${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
