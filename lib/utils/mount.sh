#!/bin/sh

mount_proc() {
  mkdir -p "$1/proc"
  mount -v -t proc none "$1/proc"
}

mount_bind_private() {
  local src=$1
  local mount=$2

  if [ -f "$src" ]; then
    touch "${mount}"
    mount -v --bind --make-private -o ro "$src" "$mount"
  fi
  if [ -d "$src" ]; then
    mkdir -p "${mount}"
    mount -v --rbind --make-rprivate -o ro "$src" "$mount"
  fi
}

mount_bind_shared() {
  local src=$1
  local mount=$2

  if [ -f "$src" ]; then
    touch "${mount}"
    mount -v --bind --make-shared "$src" "$mount"
  fi
  if [ -d "$src" ]; then
    mkdir -p "${mount}"
    mount -v --rbind --make-rshared "$src" "$mount"
  fi
}

unmount_chroot() {
  local chroot_path="$1"

  echo "Unmounting remaining filesystems..."
  # Unmounts all filesystem under the specified directory tree.
  for path in $(cat /proc/mounts | cut -d' ' -f2 | grep "^$chroot_path." | sort -r); do
    echo "Unmounting $path"
    umount -fn "$path" || echo "Could not unmount $path"
  done
  unset path
}
