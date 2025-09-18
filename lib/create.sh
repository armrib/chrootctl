#!/bin/sh

source "$LIB/db.sh"

# Function to create the chroot environment
create_chroot() {
  if [ -n "${1:-}" ]; then
    readonly chroot_name=$1
    shift
  else
    echo "Missing chroot name"
    show_help
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
  url="http://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz"
  chroot_type="alpine"

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -u | --url)
      url="$2"
      shift 2
      ;;
    -p | --path)
      chroot_dir="$2"
      shift 2
      ;;
    -t | --type)
      chroot_type="$2"
      shift 2
      ;;
    -h | --help)
      show_help_create
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help_create
      exit 1
      ;;
    esac
  done

  echo "Creating chroot with name $chroot_name at $chroot_dir/$chroot_name"
  mkdir -p "$chroot_dir/$chroot_name"

  chroot_path="$chroot_dir/$chroot_name"

  case "$chroot_type" in
  alpine)
    filename=$(basename "$url")
    if [ ! -f "/tmp/$filename" ]; then
      wget "$url" -O "/tmp/$filename"
    fi

    # Extract the file extension
    [[ "$filename" != *.tar.gz ]] && echo "Unsupported file format: $filename" >&2 && exit 1
    tar -xzf "/tmp/$filename" -C "$chroot_path"
    ;;
  debian)
    # Install debootstrap and create chroot
    if ! apk add debootstrap perl; then
      echo "Failed to install debootstrap or perl"
      exit 1
    fi
    if ! debootstrap stable "$chroot_path" http://deb.debian.org/debian/ --variant=minbase; then
      echo "Failed to create Debian chroot"
      exit 1
    fi
    apk del debootstrap perl
    ;;
  *)
    echo "Unknown chroot type: $chroot_type"
    show_help_create
    exit 1
    ;;
  esac

  # Copy resolve.conf
  cp /etc/resolv.conf "$chroot_path/etc/resolv.conf"

  mkdir -p "$chroot_path/proc"
  mount -v -t proc none "$chroot_path/proc"
  mount_bind /dev "$chroot_path/dev"
  mount_bind /sys "$chroot_path/sys"

  echo "$chroot_name $chroot_dir $chroot_type" >>$DB

  echo "Chroot environment $chroot_name created successfully."
  echo "Enter the chroot with 'enter $chroot_name'."
}

# Binds the directory $1 at the mountpoint $2 and sets propagation to private.
mount_bind() {
  src=$1
  dir=$2

  mkdir -p "$dir"
  mount -v --rbind "$src" "$dir"
  mount --make-rprivate "$dir"
}
