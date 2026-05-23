#!/bin/sh

create_alpine() {
  if [ -n "${1:-}" ]; then
    readonly chroot_path="$1"
    shift
  else
    echo "Missing chroot path"
    show_help_create_alpine
    exit 1
  fi

  local url="http://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -u | --url)
      url="$2"
      shift 2
      ;;
    -h | --help)
      show_help_create_alpine
      exit 0
      ;;
    *)
      if [ -n "${1:-}" ]; then
        echo "Unknown option ($1)"
        show_help_create_alpine
        exit 1
      else
        shift
      fi
      ;;
    esac
  done

  # Check file extension
  case "$url" in
  *.tar.gz) echo "File format tar.gz supported" ;;
  *) echo "Unsupported file format: $(basename $url)" && exit 1 ;;
  esac

  # Download the file if it doesn't exist
  if [ ! -f "$DIST_CACHE_DIR/alpine.tar.gz" ]; then
    echo "Downloading $url"
    wget "$url" -O "$DIST_CACHE_DIR/alpine.tar.gz"
  fi

  # Extract the file
  tar -xzf "$DIST_CACHE_DIR/alpine.tar.gz" -C "$chroot_path"
}

show_help_create_alpine() {
  source "$LIB/utils/colors.sh"
  printf '%b\n' "${BOLD}${BLUE}Chrootctl v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME create $(basename $chroot_path) -t alpine [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}-u, --url${NC} <url>  URL of the chroot tarball (default: http://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz)"
  printf '%b\n' "  ${GREEN}-d, --dir${NC} <path> Path to the chroot environment (default: /tmp)"
  printf '%b\n' "  ${GREEN}-h, --help${NC}       Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test -d /tmp/chroot${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
