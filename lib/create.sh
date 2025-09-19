#!/bin/sh

source "$LIB/db.sh"

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
  chroot_path=$(chroot_exists "$chroot_name")
  if [ -e "$chroot_path" ]; then
    echo "Chroot environment $chroot_name already exists."
    exit 1
  fi

  #Default values
  chroot_dir="/tmp"
  chroot_type="alpine"
  chroot_shell="/bin/sh"

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
        chroot_mount_private="${chroot_mount_private:-}$2 "
        shift 2
        ;;
      --mount-shared)
        chroot_mount_shared="${chroot_mount_shared:-}$2 "
        shift 2
        ;;
      --from-local)
        chroot_from_local="$2"
        shift 2
        ;;
      *)
        args="${args:-}$1 "
        shift
        ;;
    esac
  done
  chroot_path="$chroot_dir/$chroot_name"

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
        create_alpine "$chroot_path" "${args:-}"
        ;;
      debian)
        source "$LIB/create/debian.sh"
        create_debian "${chroot_path}" "${args:-}"
        ;;
      *)
        echo "Unknown chroot type: $chroot_type"
        show_help_create
        exit 1
        ;;
    esac
  fi

  # Mounts all given read-only mount points
  chroot_mount_private=${chroot_mount_private:-default}
  for mount_private in $chroot_mount_private; do
    case "$mount_private" in
      default)
        echo "Mounting default private mount points..."
        mount_proc "$chroot_path"
        mount_bind_private /dev "$chroot_path/dev"
        mount_bind_private /sys "$chroot_path/sys"
        ;;
      /*)
        echo "Mounting private mount point $mount_private..."
        case "$mount_private" in
          /proc*)
            mount_proc "$chroot_path"
            ;;
          *)
            mount_bind_private "$mount_private" "${chroot_path}${mount_private}"
            ;;
        esac
        ;;
      *)
        echo "Error: Invalid private mount point: $mount_private"
        ;;
    esac
  done
  chroot_mount_private=$(echo $chroot_mount_private | tr ' ' ',')

  # Mounts all given read-write mount points
  for mount_shared in ${chroot_mount_shared:-}; do
    case "$mount_shared" in
      /*)
        echo "Mounting shared mount point $mount_shared..."
        mount_bind_shared "$mount_shared" "${chroot_path}${mount_shared}"
        ;;
      *)
        echo "Error: Invalid shared mount point: $mount_shared"
        ;;
    esac
  done
  chroot_mount_shared=$(echo ${chroot_mount_shared:-none} | tr ' ' ',')

  echo "$chroot_name $chroot_dir $chroot_type $chroot_shell $chroot_mount_private $chroot_mount_shared" >>"$DB"

  echo "Chroot environment $chroot_name created successfully."
  echo "Enter the chroot with '$PROGRAM_NAME enter $chroot_name'."
}

mount_proc() {
  mkdir -p "$1/proc"
  mount -v -t proc none "$1/proc"
}
# Binds the directory $1 at the mountpoint $2 and sets propagation to private.
mount_bind_private() {
  src=$1
  mount=$2

  if [ -f "$src" ]; then
    touch "${mount}"
    mount -v --bind "$src" "$mount"
    mount -v --make-private "$mount"
  fi
  if [ -d "$src" ]; then
    mkdir -p "${mount}"
    mount -v --rbind "$src" "$mount"
    mount -v --make-rprivate "$mount"
  fi
}

mount_bind_shared() {
  src=$1
  mount=$2

  if [ -f "$src" ]; then
    touch "${mount}"
    mount -v --bind "$src" "$mount"
    mount -v --make-shared "$mount"
  fi
  if [ -d "$src" ]; then
    mkdir -p "${mount}"
    mount -v --rbind "$src" "$mount"
    mount -v --make-rshared "$mount"
  fi
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
