#!/bin/sh

source "$LIB/db.sh"

# Function to delete the chroot environment
delete_chroot() {
  if [ -n "${1:-}" ]; then
    chroot_name=$1
    shift
  else
    echo "Missing chroot name"
    show_help
    exit 1
  fi

  # Check if the name exists
  chroot_path=$(chroot_exists "$chroot_name")
  if [ -z "$chroot_path" ]; then
    echo "Chroot environment $chroot_name does not exist."
    exit 1
  fi

  # Kill all processes that have some file opened in the chroot, except this script.
  echo 'Terminating remaining processes in the chroot...'
  found=false
  if ! kill_chroot "$chroot_path"; then
    echo "Found processes in chroot..."
    found=true
  fi
  while $found; do
    echo 'Waiting 5 sec for processes to terminate before killing them...'
    sleep 5
    if kill_chroot "$chroot_path" true; then
      found=false
    fi
  done


  # Unmounts all filesystem under the specified directory tree.
  for path in $(cat /proc/mounts | cut -d' ' -f2 | grep "^$chroot_path." | sort -r); do
    echo "Unmounting $path"
    umount -fn "$path"
  done

  echo "Removing $chroot_path"
  rm -rf "$chroot_path"

  # Remove chroot from DB
  echo "Removing chroot from DB..."
  sed -i "/^${chroot_name}/d" "$DB"

  echo "Chroot environment $chroot_name deleted successfully."
}

kill_chroot() {
  chroot_path=$1
  force=${2:-false}

  found=0
  for proc_root in /proc/*/root; do
    link=$(readlink $proc_root)
    if [ "x$link" != "x" ]; then
        if [ "x${link:0:${#chroot_path}}" = "x$chroot_path" ]; then
            # this process is in the chroot...
            pid=$(basename $(dirname "$proc_root"))
            if [ $force = true ]; then
              echo "Sending SIGKILL to $pid"
              kill -9 "$pid"
            else
              echo "Sending SIGTERM to $pid"
              kill "$pid"
            fi
            found=1
        fi
    fi
  done
  return $found
}
