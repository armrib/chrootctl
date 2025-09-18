#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Function to check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# Global variables
readonly PROGRAM_NAME="chrootctl"
readonly VERSION="0.1.0"
readonly REPOSITORY="https://github.com/armrib/alpine-chrootctl"
readonly SCRIPT_NAME=$(basename $0)

if [ "$SCRIPT_NAME" = "main.sh" ]; then
  readonly LIB="./lib"
  readonly DB="./.db"
else
  readonly LIB="/opt/chrootctl/lib"
  readonly DB="/var/lib/chrootctl/db"
fi

source "$LIB/help.sh"

# Parse command-line arguments
if [ -n "${1:-}" ]; then
  readonly COMMAND=$1
  shift
else
  show_help
  exit 1
fi

# Main script logic
case "$COMMAND" in
create)
  source "$LIB/create.sh"
  create_chroot $@
  ;;
enter)
  source "$LIB/enter.sh"
  enter_chroot $@
  ;;
delete)
  source "$LIB/delete.sh"
  delete_chroot $1
  ;;
list)
  source "$LIB/list.sh"
  list_chroots
  ;;
version)
  echo "Chrootctl v${VERSION}"
  ;;
*)
  show_help
  ;;
esac
