#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Escalate to root with doas if not already running as root
if [ "$(id -u)" -ne 0 ]; then
  exec doas "$0" "$@"
fi

# Global variables
readonly PROGRAM_NAME="chrootctl"
readonly VERSION="0.4.0"
readonly REPOSITORY="https://github.com/armrib/chrootctl"
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
  source "$LIB/utils/colors.sh"
  printf '%b\n' "${BOLD}${BLUE}Chrootctl v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME {action} [options]"
  printf '%b\n' "${BOLD}${CYAN}Actions:${NC}"
  printf '%b\n' "  ${GREEN}create${NC} Create a chroot environment"
  printf '%b\n' "  ${GREEN}enter${NC}  Enter a chroot environment"
  printf '%b\n' "  ${GREEN}save${NC}   Save a chroot environment"
  printf '%b\n' "  ${GREEN}delete${NC} Delete a chroot environment"
  printf '%b\n' "  ${GREEN}list${NC}   List all chroot environments"
  printf '%b\n' "  ${GREEN}cache${NC}  List all cached distributions"
  printf '%b\n' "  ${GREEN}saved${NC}  List all saved chroot environments"
  printf '%b\n' "  ${GREEN}help${NC}   Show help"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME enter test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME delete test${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
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
