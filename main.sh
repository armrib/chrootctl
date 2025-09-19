#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Function to check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# Global variables
readonly PROGRAM_NAME="chrootctl"
readonly VERSION="0.2.0"
readonly REPOSITORY="https://github.com/armrib/alpine-chrootctl"
readonly SCRIPT_NAME=$(basename $0)

# Global variables based on script name
if [ "$SCRIPT_NAME" = "main.sh" ]; then
  readonly LIB="lib"
  readonly DB="$PWD/.db"
  readonly DIST_CACHE_DIR="$PWD/.cache/dist"
  mkdir -p "$DIST_CACHE_DIR"
  readonly CHROOT_CACHE_DIR="$PWD/.cache/chroot"
  mkdir -p "$CHROOT_CACHE_DIR"
else
  readonly LIB="/opt/$PROGRAM_NAME/lib"
  readonly DB="/var/lib/$PROGRAM_NAME/db"
  readonly DIST_CACHE_DIR="/var/cache/$PROGRAM_NAME/dist"
  readonly CHROOT_CACHE_DIR="/var/cache/$PROGRAM_NAME/chroot"
fi

show_help() {
  cat <<EOF
Chrootctl v${VERSION}
Usage: $PROGRAM_NAME {action} [options]
Actions:
  create Create a chroot environment
  enter  Enter a chroot environment
  save   Save a chroot environment
  delete Delete a chroot environment
  list   List all chroot environments
  cache  List all cached distributions
  saved  List all saved chroot environments
  help   Show help
Examples:
  $PROGRAM_NAME create test
  $PROGRAM_NAME enter test
  $PROGRAM_NAME delete test
For more information, visit: $REPOSITORY
EOF
}

# Parse command-line arguments
if [ -n "${1:-}" ]; then
  readonly COMMAND="$1"
  shift
else
  show_help
  exit 1
fi

# Main script logic
case "$COMMAND" in
  create)
    source "$LIB/create.sh"
    create_chroot "$@"
    ;;
  enter)
    source "$LIB/enter.sh"
    enter_chroot "$@"
    ;;
  save)
    source "$LIB/save.sh"
    save_chroot "$@"
    ;;
  delete)
    source "$LIB/delete.sh"
    delete_chroot "$@"
    ;;
  list)
    source "$LIB/list.sh"
    list_chroots
    ;;
  cache)
    source "$LIB/cache.sh"
    list_cache
    ;;
  saved)
    source "$LIB/saved.sh"
    list_saved
    ;;
  version)
    echo "Chrootctl v${VERSION}"
    ;;
  *)
    show_help
    ;;
esac
