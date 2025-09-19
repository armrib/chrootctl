#!/bin/sh

source "$LIB/db.sh"

# Function to enter the chroot environment
enter_chroot() {
  if [ -n "${1:-}" ]; then
    readonly chroot_name=$1
    shift
  else
    echo "Error: Missing chroot name!"
    show_help_enter
    exit 1
  fi

  # Check if the name exists
  chroot_params=$(chroot_exists "$chroot_name" all)
  if [ -z "$chroot_params" ]; then
    echo "Chroot environment $chroot_name does not exist."
    exit 1
  fi

  chroot_dir=$(echo "$chroot_params" | awk '{print $2}')
  chroot_type=$(echo "$chroot_params" | awk '{print $3}')
  chroot_shell=$(echo "$chroot_params" | awk '{print $4}')
  chroot_mount_ro=$(echo "$chroot_params" | awk '{print $5}')
  chroot_mount_rw=$(echo "$chroot_params" | awk '{print $6}')

  chroot_path="${chroot_dir}/${chroot_name}"
  chroot_shell=${chroot_shell:-/bin/sh}

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --shell)
        chroot_shell="$2"
        shift 2
        ;;
      -h | --help)
        show_help_enter
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done

  echo "Entering chroot environment $chroot_name in $chroot_dir..."
  chroot "$chroot_path" "$chroot_shell"
}

show_help_enter() {
  cat <<EOF
Chrootctl enter v${VERSION}
Usage: $PROGRAM_NAME enter ${chroot_name:-} [options]
Options:
  --shell <shell>       Default shell to use (default: /bin/sh)
  -h, --help            Show this help message
Examples:
  $PROGRAM_NAME enter test
  $PROGRAM_NAME enter test --shell /bin/bash
For more information, visit: $REPOSITORY
EOF
}
