#!/bin/sh

source "$LIB/utils/db.sh"

# Function to create the chroot environment
create_chroot() {
  if [ -n "${1:-}" ]; then
    case "$1" in
    [A-Za-z]*)
      readonly chroot_name="$1"
      shift
      ;;
    *)
      echo "Error: Chroot name must start with a letter!"
      show_help
      exit 1
      ;;
    esac
  else
    echo "Missing chroot name"
    show_help_create
    exit 1
  fi

  # Check if the name exists
  local chroot_path=$(chroot_exists "$chroot_name")
  if [ -e "$chroot_path" ]; then
    echo "Chroot environment $chroot_name already exists."
    exit 1
  fi

  if sysctl -ne kernel.grsecurity.chroot_deny_chmod; then
    echo "Warning: can't suid/sgid inside chroot" >&2
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_chroot; then
    echo "Warning: can't chroot inside chroot" >&2
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_mknod; then
    echo "Warning: can't mknod inside chroot" >&2
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_mount; then
    echo "Warning: can't mount inside chroot" >&2
  fi

  #Default values
  local chroot_dir="/tmp"
  local chroot_type="alpine"
  local chroot_shell="/bin/sh"

  case "${1:-}" in
  -h | --help)
    show_help_create
    exit 0
    ;;
  *) ;;
  esac

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -d | --dir)
      chroot_dir="$2"
      shift 2
      ;;
    -t | --type)
      chroot_type="$2"
      shift 2
      ;;
    --shell)
      chroot_shell="$2"
      shift 2
      ;;
    --mount-private)
      local chroot_mount_private="${chroot_mount_private:-}$2 "
      shift 2
      ;;
    --mount-shared)
      local chroot_mount_shared="${chroot_mount_shared:-}$2 "
      shift 2
      ;;
    --from-local)
      local chroot_from_local="$2"
      shift 2
      ;;
    *)
      local args="${args:-}$1 "
      shift
      ;;
    esac
  done
  local chroot_path="$chroot_dir/$chroot_name"

  echo "Creating chroot with name $chroot_name in $chroot_dir..."
  mkdir -p "$chroot_path"

  if [ -n "${chroot_from_local:-}" ]; then
    echo "Restoring chroot from local cache $chroot_from_local..."
    # Extract the file
    tar -xzf "$CHROOT_CACHE_DIR/${chroot_from_local}.tar.gz" -C "$chroot_path"
  else
    case "$chroot_type" in
    alpine)
      source "$LIB/create/alpine.sh"
      create_alpine "$chroot_path" ${args:-}
      ;;
    debian)
      source "$LIB/create/debian.sh"
      create_debian "${chroot_path}" ${args:-}
      ;;
    arch)
      source "$LIB/create/arch.sh"
      create_arch "${chroot_path}" ${args:-}
      ;;
    *)
      echo "Unknown chroot type: $chroot_type"
      show_help_create
      exit 1
      ;;
    esac
  fi

  source "$LIB/utils/mount.sh"
  source "$LIB/utils/trim.sh"
  # Mounts all given read-only mount points
  local private_mounts=""
  for mount_private in default ${chroot_mount_private:-}; do
    case "$mount_private" in
    default)
      echo "Mounting default private mount points..."
      mount_proc "$chroot_path"
      mount_bind_private /dev "$chroot_path/dev"
      mount_bind_private /sys "$chroot_path/sys"
      [ "$chroot_type" = "arch" ] && mount_bind_private /dev/pts "$chroot_path/dev/pts"
      private_mounts="$private_mounts default"
      ;;
    /*)
      echo "Mounting private mount point $mount_private..."
      case "$mount_private" in
      /proc*) echo "Mount /proc already mounted by default!" ;;
      /dev*) echo "Mount /dev already mounted by default!" ;;
      /sys*) echo "Mount /sys already mounted by default!" ;;
      *)
        mount_bind_private "$mount_private" "${chroot_path}${mount_private}"
        private_mounts="$private_mounts $mount_private"
        ;;
      esac
      ;;
    *)
      [ -z "$mount_private" ] && echo "Error: Invalid private mount point: $mount_private, skipping..." && continue
      echo "Warn: Invalid private mount point: $mount_private"
      source "$LIB/utils/abs-path.sh"
      echo "Warn: Transforming relative path ($mount_private) to absolute path..."
      local abs_mount_private=$(abs_path $mount_private)
      chroot_mount_private=$(echo $chroot_mount_private | sed "s#$mount_private#$abs_mount_private#g")
      mount_private=$abs_mount_private
      echo "Mounting private mount point $mount_private..."
      mount_bind_private "$mount_private" "${chroot_path}${mount_private}"
      private_mounts="$private_mounts $mount_private"
      ;;
    esac
  done
  unset mount_private
  private_mounts=$(trim "$private_mounts")
  chroot_mount_private=$(echo $private_mounts | tr ' ' ',')

  # Mounts all given read-write mount points
  local shared_mounts=""
  for mount_shared in ${chroot_mount_shared:-}; do
    case "$mount_shared" in
    /*)
      echo "Mounting shared mount point $mount_shared..."
      mount_bind_shared "$mount_shared" "${chroot_path}${mount_shared}"
      shared_mounts="$shared_mounts $mount_shared"
      ;;
    *)
      [ -z "$mount_shared" ] && echo "Error: Invalid shared mount point: $mount_shared" && continue
      echo "Warn: Invalid shared mount point: $mount_shared"
      source "$LIB/utils/abs-path.sh"
      echo "Warn: Transforming relative path ($mount_shared) to absolute path..."
      local abs_mount_shared=$(abs_path $mount_shared)
      chroot_mount_shared=$(echo $chroot_mount_shared | sed "s#$mount_shared#$abs_mount_shared#g")
      mount_shared=$abs_mount_shared
      echo "Mounting private mount point $mount_shared..."
      mount_bind_shared "$mount_shared" "${chroot_path}${mount_shared}"
      shared_mounts="$shared_mounts $mount_shared"
      ;;
    esac
  done
  unset mount_shared
  shared_mounts=$(trim "$shared_mounts")
  chroot_mount_shared=$(echo ${shared_mounts:-none} | tr ' ' ',')

  echo "$chroot_name $chroot_dir $chroot_type $chroot_shell $chroot_mount_private $chroot_mount_shared" >>"$DB"

  echo "Chroot environment $chroot_name created successfully."
  echo "Enter the chroot with '$PROGRAM_NAME enter $chroot_name'."
}

show_help_create() {
  cat <<EOF
Chrootctl create v${VERSION}
Usage: $PROGRAM_NAME create [options]
Options:
  -t, --type      <type>  Type of chroot environment (alpine, debian) (default: alpine)
  -d, --dir       <path>  Path to the chroot environment (default: /tmp)
  --shell         <shell> Default shell to use (default: /bin/sh)
  --mount-private <path>  Private mount point (default, [path])
  --mount-shared  <path>  Shared mount point
  --from-local    <name>  Restore chroot from local cache
  -h, --help              Show this help message
Examples:
  $PROGRAM_NAME create test
  $PROGRAM_NAME create test -d /tmp/chroot
  $PROGRAM_NAME create test --mount-private default
  $PROGRAM_NAME create test --mount-shared /your/path
For more information, visit: $REPOSITORY
EOF
}
