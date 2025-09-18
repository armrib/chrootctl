#!/bin/sh

source "$LIB/db.sh"

# Function to enter the chroot environment
enter_chroot() {
  if [ -n "${1:-}" ]; then
    readonly chroot_name=$1
    shift
  else
    echo "Missing chroot name"
    show_help
    exit 1
  fi

  # Check if the name exists
  readonly chroot_path=$(chroot_exists "$chroot_name")
  if [ -z "$chroot_path" ]; then
    echo "Chroot environment $chroot_name does not exist."
    exit 1
  fi

  echo "Entering chroot environment $chroot_name..."
  chroot "$chroot_path" /bin/sh
}
