#!/bin/sh

source "$LIB/utils/db.sh"

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
  local chroot_params=$(chroot_exists "$chroot_name" all)
  if [ -z "$chroot_params" ]; then
    echo "Chroot environment $chroot_name does not exist."
    exit 1
  fi

  local chroot_dir=$(echo "$chroot_params" | awk '{print $2}')
  local chroot_type=$(echo "$chroot_params" | awk '{print $3}')
  local chroot_shell=$(echo "$chroot_params" | awk '{print $4}')
  local chroot_mount_private=$(echo "$chroot_params" | awk '{print $5}')
  local chroot_mount_shared=$(echo "$chroot_params" | awk '{print $6}')

  local chroot_path="${chroot_dir}/${chroot_name}"
  local chroot_shell=${chroot_shell:-/bin/sh}

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

  local private_mounts=$(echo "$chroot_mount_private" | tr ',' ' ' | sed "s#default#/proc /dev $([ $chroot_type = "arch" ] && echo /dev/pts) /sys#g")
  local shared_mounts=$(echo "$chroot_mount_shared" | tr ',' ' ')
  local current_mounts=$(cat /proc/mounts | cut -d' ' -f2)

  echo "Check missing private mount points..."
  for private_mount in $private_mounts; do
    if ! echo "$current_mounts" | grep -q "^${chroot_path}${private_mount}"; then
      echo "Warn: Mount point $private_mount is not mounted, mounting..."
      source "$LIB/utils/mount.sh"
      case "$private_mount" in
      /proc*) mount_proc "$chroot_path" ;;
      /*) mount_bind_private "$private_mount" "${chroot_path}${private_mount}" ;;
      *) echo "Error: Invalid private mount point: $private_mount" && exit 1 ;;
      esac
    fi
  done
  unset private_mount

  echo "Check missing shared mount points..."
  for shared_mount in $(echo "$shared_mounts" | sed 's#none##g'); do
    if ! echo "$current_mounts" | grep -q "^${chroot_path}${shared_mount}"; then
      echo "Warn: Mount point $shared_mount is not mounted, mounting..."
      source "$LIB/utils/mount.sh"
      case "$shared_mount" in
      /*) mount_bind_shared "$shared_mount" "${chroot_path}${shared_mount}" ;;
      *) echo "Error: Invalid private mount point: $shared_mount" && exit 1 ;;
      esac
    fi
  done
  unset shared_mount

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
