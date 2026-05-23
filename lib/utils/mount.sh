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

mount_bind_ro() {
  local src=$1
  local dest=$2

  if [ -f "$src" ]; then
    touch "$dest"
    mount -v --bind -o ro "$src" "$dest"
  elif [ -d "$src" ]; then
    mkdir -p "$dest"
    mount -v --rbind -o ro "$src" "$dest"
  fi
}

mount_bind_rw() {
  local src=$1
  local dest=$2

  if [ -f "$src" ]; then
    touch "$dest"
    mount -v --bind "$src" "$dest"
  elif [ -d "$src" ]; then
    mkdir -p "$dest"
    mount -v --rbind "$src" "$dest"
  fi
}

unmount_chroot() {
  local chroot_path="$1"
  local chroot_mount_shared="${2:-}"
  local chroot_mount_private="${3:-}"

  echo "Unmounting remaining filesystems..."

  # Get all mounts under chroot_path and unmount in reverse order (deepest first)
  local all_mounts=$(mount | grep "^[^ ]* on ${chroot_path}" | awk '{print $3}' | sort -r)
  for mount_point in $all_mounts; do
    if mountpoint -q "$mount_point" 2>/dev/null; then
      echo "Unmounting: $mount_point"
      umount -fn "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
    fi
  done
}
