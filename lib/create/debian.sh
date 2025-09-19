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

  suite="stable"

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
  cat <<EOF
Chrootctl v${VERSION}
Usage: $PROGRAM_NAME create $(basename chroot_path) -t debian [options]
Options:
  -s, --suite <suite> Debian suite to use (stable, testing, ...) (default: stable)
  -d, --dir   <path>  Path to the chroot environment (default: /tmp)
  -h, --help          Show this help message
Examples:
  $PROGRAM_NAME create test
  $PROGRAM_NAME create test -d /tmp/chroot
For more information, visit: $REPOSITORY
EOF
}
