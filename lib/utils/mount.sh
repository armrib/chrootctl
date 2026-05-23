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

  # Unmount custom shared mounts first (in reverse order)
  if [ -n "$chroot_mount_shared" ] && [ "$chroot_mount_shared" != "none" ]; then
    echo "$chroot_mount_shared" | tr ',' '\n' | tac | while read -r mount_path; do
      [ -z "$mount_path" ] && continue
      local mount_point="${chroot_path}${mount_path}"
      if mountpoint -q "$mount_point" 2>/dev/null; then
        echo "Unmounting shared mount: $mount_point"
        umount -fn "$mount_point" || umount -l "$mount_point" || true
      fi
    done
  fi

  # Unmount custom private mounts (in reverse order)
  if [ -n "$chroot_mount_private" ] && [ "$chroot_mount_private" != "none" ]; then
    echo "$chroot_mount_private" | tr ',' '\n' | tac | while read -r mount_path; do
      [ -z "$mount_path" ] && continue
      # Skip default mounts (handled below)
      case "$mount_path" in
      default) continue ;;
      esac
      local mount_point="${chroot_path}${mount_path}"
      if mountpoint -q "$mount_point" 2>/dev/null; then
        echo "Unmounting private mount: $mount_point"
        umount -fn "$mount_point" || umount -l "$mount_point" || true
      fi
    done
  fi

  # Unmount default mounts in reverse order
  for mount_point in "${chroot_path}/dev/pts" "${chroot_path}/sys" "${chroot_path}/dev" "${chroot_path}/proc"; do
    if mountpoint -q "$mount_point" 2>/dev/null; then
      echo "Unmounting: $mount_point"
      umount -fn "$mount_point" || umount -l "$mount_point" || true
    fi
  done
}
