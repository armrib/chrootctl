#!/bin/sh

source "$LIB/db.sh"

# Function to delete the chroot environment
delete_chroot() {
  if [ -n "${1:-}" ]; then
    chroot_name=$1
    shift
  else
    echo "Missing chroot name"
    show_help_delete
    exit 1
  fi

  chroot_dir=$(chroot_exists "$chroot_name" dir)
  chroot_path="${chroot_dir}/${chroot_name}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -f | --force)
      chroot_dir="$2"
      chroot_path="${chroot_dir}/${chroot_name}"
      shift 2
      ;;
    -h | --help)
      show_help_delete
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
    esac
  done

  # Check if the name exists
  if [ -z "$chroot_path" ]; then
    echo "Chroot environment $chroot_name ${chroot_dir:+at $chroot_dir} does not exist."
    exit 1
  fi

  # Wait for all chroot processes to terminate
  wait_and_kill_all_chroot_process "$chroot_path"

  # Unmount all filesystems under the chroot
  unmount_chroot "$chroot_path"

  echo "Removing $chroot_path"
  rm -rf "$chroot_path"

  # Remove chroot from DB (POSIX-compliant)
  if [ -f "$DB" ] && [ -w "$DB" ]; then
    echo "Removing chroot from DB..."
    tmpfile=$(mktemp) || {
      echo "Error: Failed to create temporary file." >&2
      exit 1
    }
    trap 'rm -f "$tmpfile"' EXIT INT TERM HUP

    # Delete matching lines and write to temporary file
    sed "/^${chroot_name}/d" "$DB" >"$tmpfile" && mv "$tmpfile" "$DB"

    # Cleanup
    rm -f "$tmpfile"
    trap - EXIT INT TERM HUP
  else
    echo "Error: Database file $DB does not exist or is not writable." >&2
    exit 1
  fi

  echo "Chroot environment $chroot_name deleted successfully."
}

wait_and_kill_all_chroot_process() {
  chroot_path="$1"
  # Kill all processes that have some file opened in the chroot, except this script.
  echo 'Terminating remaining processes in the chroot...'
  if ! kill_chroot_process "$chroot_path"; then
    echo "Found processes in chroot, sending SIGTERM..."
    processes_remaining=true
  else
    processes_remaining=false
  fi
  while $processes_remaining; do
    echo 'Waiting 5 sec for processes to terminate before killing them...'
    sleep 5
    if ! kill_chroot_process "$chroot_path" true; then
      processes_remaining=false
    fi
  done

}

unmount_chroot() {
  chroot_path="$1"
  # Unmounts all filesystem under the specified directory tree.
  echo "Unmounting remaining filesystems..."
  for path in $(cat /proc/mounts | cut -d' ' -f2 | grep "^$chroot_path." | sort -r); do
    echo "Unmounting $path"
    umount -fn "$path"
  done
}

kill_chroot_process() {
  chroot_path="$1"
  force="${2:-false}"
  found=0

  for proc_root in /proc/[0-9]*/root; do
    if [ -L "$proc_root" ]; then
      link=$(readlink "$proc_root" 2>/dev/null)
      if [ -n "$link" ]; then
        # POSIX-compliant string prefix check
        case "$link" in
        "$chroot_path"*)
          pid=$(basename "$(dirname "$proc_root")")
          if [ "$force" = "true" ]; then
            echo "Sending SIGKILL to $pid"
            kill -9 "$pid"
          else
            echo "Sending SIGTERM to $pid"
            kill "$pid"
          fi
          found=1
          ;;
        esac
      fi
    fi
  done

  return "$found"
}

show_help_delete() {
  cat <<EOF
Chrootctl delete v${VERSION}
Usage: $PROGRAM_NAME delete ${chroot_name:-} [options]
Options:
  -f, --force           Force deletion of the chroot environment
  -h, --help            Show this help message
Examples:
  $PROGRAM_NAME delete test
  $PROGRAM_NAME delete test --force /tmp/chroot
For more information, visit: $REPOSITORY
EOF
}
