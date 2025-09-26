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
  if [ ! -f "$DIST_CACHE_DIR/arch-bootstrap.sh" ]; then
    echo "Downloading $url"
    wget "$url" -O "$DIST_CACHE_DIR/arch-bootstrap.sh"
  fi

  # Extract the file
  apk add bash zstd curl
  bash "$DIST_CACHE_DIR/arch-bootstrap.sh" "$chroot_path"
}

show_help_create_alpine() {
  cat <<EOF
Chrootctl v${VERSION}
Usage: $PROGRAM_NAME create $(basename $chroot_path) -t arch [options]
Options:
  -h, --help       Show this help message
Examples:
  $PROGRAM_NAME create test -t arch
  $PROGRAM_NAME create test -t arch -d /tmp/chroot
For more information, visit: $REPOSITORY
EOF
}
