#!/bin/sh

source "$LIB/utils/db.sh"
source "$LIB/utils/colors.sh"
source "$LIB/utils/env.sh"
source "$LIB/utils/trim.sh"

# Function to create the chroot environment
create_chroot() {
  if [ -n "${1:-}" ]; then
    case "$1" in
    [A-Za-z]*)
      readonly chroot_name="$1"
      shift
      ;;
    *)
      error "Chroot name must start with a letter!"
      show_help
      exit 1
      ;;
    esac
  else
    error "Missing chroot name"
    show_help_create
    exit 1
  fi

  # Check if the name exists
  local chroot_path=$(chroot_exists "$chroot_name")
  if [ -e "$chroot_path" ]; then
    error "Chroot environment $chroot_name already exists."
    exit 1
  fi

  if sysctl -ne kernel.grsecurity.chroot_deny_chmod; then
    warning "can't suid/sgid inside chroot"
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_chroot; then
    warning "can't chroot inside chroot"
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_mknod; then
    warning "can't mknod inside chroot"
  fi
  if sysctl -ne kernel.grsecurity.chroot_deny_mount; then
    warning "can't mount inside chroot"
  fi

  #Default values
  local chroot_dir="/var/lib/chrootctl"
  local chroot_type="alpine"
  local chroot_shell="/bin/sh"
  local chroot_user="none"
  local chroot_env=""
  local chroot_version="latest"
  local chroot_arch=""

  case "${1:-}" in
  -h | --help)
    show_help_create
    exit 0
    ;;
  *) ;;
  esac

  # Pre-pass: if --from is given, load saved metadata as defaults so
  # explicit CLI args parsed below can override individual fields
  {
    local _fl_found=false
    for _arg in "$@"; do
      if [ "$_fl_found" = "true" ]; then
        if [ -f "$CHROOT_CACHE_DIR/${_arg}.meta" ]; then
          local _meta
          _meta=$(cat "$CHROOT_CACHE_DIR/${_arg}.meta")
          chroot_dir=$(echo "$_meta"   | awk '{print $2}')
          chroot_type=$(echo "$_meta"  | awk '{print $3}')
          chroot_shell=$(echo "$_meta" | awk '{print $4}')
          chroot_mount_private=$(echo "$_meta" | awk '{print $5}' | tr ',' ' ')
          chroot_mount_shared=$(echo "$_meta"  | awk '{print $6}' | tr ',' ' ')
          chroot_bind_ro=$(echo "$_meta"       | awk '{print $7}' | tr ',' ' ')
          chroot_bind_rw=$(echo "$_meta"       | awk '{print $8}' | tr ',' ' ')
          chroot_user=$(echo "$_meta"  | awk '{print $9}')
          chroot_version=$(echo "$_meta" | awk '{print $10}')
          chroot_arch=$(echo "$_meta" | awk '{print $11}')
        fi
        break
      fi
      [ "$_arg" = "--from" ] && _fl_found=true
    done
    unset _fl_found _arg _meta
  }

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
    --bind-ro)
      local chroot_bind_ro="${chroot_bind_ro:-}$2 "
      shift 2
      ;;
    --bind-rw)
      local chroot_bind_rw="${chroot_bind_rw:-}$2 "
      shift 2
      ;;
    --from)
      local chroot_from_local="$2"
      shift 2
      ;;
    --user)
      chroot_user="$2"
      shift 2
      ;;
    --env)
      if ! parse_env_vars "$2"; then
        error "Invalid environment variables: $2"
        echo "Format: KEY=VALUE,KEY2=VALUE2"
        exit 1
      fi
      chroot_env=$(trim "$parsed_env")
      shift 2
      ;;
    --pkg)
      chroot_packages="${chroot_packages:-},$2"
      shift 2
      ;;
    --version)
      chroot_version="$2"
      shift 2
      ;;
    --arch)
      chroot_arch="$2"
      shift 2
      ;;
    --suite)
      chroot_version="$2"
      shift 2
      ;;
    *)
      local args="${args:-}$1 "
      shift
      ;;
    esac
  done
  local chroot_path="$chroot_dir/$chroot_name"

  info "Creating chroot with name $chroot_name in $chroot_dir..."
  mkdir -p "$chroot_path"

  if [ -n "${chroot_from_local:-}" ]; then
    info "Restoring chroot from local cache $chroot_from_local..."
    tar -xzf "$CHROOT_CACHE_DIR/${chroot_from_local}.tar.gz" -C "$chroot_path"
  else
    case "$chroot_type" in
    alpine)
      source "$LIB/create/alpine.sh"
      create_alpine "$chroot_path" "$chroot_version" "$chroot_arch"
      ;;
    debian)
      source "$LIB/create/debian.sh"
      create_debian "$chroot_path" "$chroot_suite"
      ;;
    arch)
      source "$LIB/create/arch.sh"
      create_arch "${chroot_path}"
      ;;
    *)
      error "Unknown chroot type: $chroot_type"
      show_help_create
      exit 1
      ;;
    esac
  fi

  if [ -n "${chroot_packages:-}" ]; then
    local pkgs
    pkgs=$(echo "$chroot_packages" | sed 's/^,//' | tr ',' ' ')

    # Set up DNS in the chroot for package installation
    if [ ! -f "$chroot_path/etc/resolv.conf" ] || [ ! -s "$chroot_path/etc/resolv.conf" ]; then
      cp /etc/resolv.conf "$chroot_path/etc/resolv.conf" 2>/dev/null || true
    fi

    info "Installing packages: $pkgs"
    case "$chroot_type" in
    alpine)
      chroot "$chroot_path" apk add --no-cache $pkgs || {
        error "Failed to install packages: $pkgs"
        exit 1
      }
      ;;
    *)
      error "Package installation not supported for $chroot_type"
      exit 1
      ;;
    esac
  fi

  if [ "$chroot_user" != "none" ]; then
    case "$chroot_type" in
    alpine)
      info "Creating user $chroot_user..."
      chroot "$chroot_path" adduser -D "$chroot_user"
      ;;
    *)
      info "Creating user $chroot_user..."
      chroot "$chroot_path" useradd -m "$chroot_user"
      ;;
    esac
  fi

  source "$LIB/utils/mount.sh"
  source "$LIB/utils/trim.sh"
  # Mounts all given read-only mount points
  local private_mounts=""
  for mount_private in default ${chroot_mount_private:-}; do
    [ "$mount_private" = "none" ] && continue
    case "$mount_private" in
    default)
      info "Mounting default private mount points..."
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
      chroot_mount_private=$(echo "$chroot_mount_private" | sed "s|$(printf '%s\n' "$mount_private" | sed 's/[&/\]/\\&/g')|$(printf '%s\n' "$abs_mount_private" | sed 's/[&/\]/\\&/g')|g")
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
    [ "$mount_shared" = "none" ] && continue
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
      chroot_mount_shared=$(echo "$chroot_mount_shared" | sed "s|$(printf '%s\n' "$mount_shared" | sed 's/[&/\]/\\&/g')|$(printf '%s\n' "$abs_mount_shared" | sed 's/[&/\]/\\&/g')|g")
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

  # Handle read-only bind mounts (source:destination)
  local bind_ro_list=""
  for bind_spec in ${chroot_bind_ro:-}; do
    [ -z "$bind_spec" ] && continue
    [ "$bind_spec" = "none" ] && continue
    local src=$(echo "$bind_spec" | cut -d: -f1)
    local dest=$(echo "$bind_spec" | cut -d: -f2-)

    src=$(eval echo "$src")
    if [ -e "$src" ]; then
      info "Mounting read-only bind: $src -> $dest"
      mount_bind_ro "$src" "${chroot_path}${dest}"
      bind_ro_list="$bind_ro_list $bind_spec"
    else
      error "Source path does not exist: $src"
      exit 1
    fi
  done
  bind_ro_list=$(trim "$bind_ro_list")
  chroot_bind_ro=$(echo ${bind_ro_list:-none} | tr ' ' ',')

  # Handle read-write bind mounts (source:destination)
  local bind_rw_list=""
  for bind_spec in ${chroot_bind_rw:-}; do
    [ -z "$bind_spec" ] && continue
    [ "$bind_spec" = "none" ] && continue
    local src=$(echo "$bind_spec" | cut -d: -f1)
    local dest=$(echo "$bind_spec" | cut -d: -f2-)

    src=$(eval echo "$src")
    if [ -e "$src" ]; then
      info "Mounting read-write bind: $src -> $dest"
      mount_bind_rw "$src" "${chroot_path}${dest}"
      bind_rw_list="$bind_rw_list $bind_spec"
    else
      error "Source path does not exist: $src"
      exit 1
    fi
  done
  bind_rw_list=$(trim "$bind_rw_list")
  chroot_bind_rw=$(echo ${bind_rw_list:-none} | tr ' ' ',')

  info "Setting up shell environment in chroot..."
  mkdir -p "$chroot_path/root"
  cat >> "$chroot_path/root/.profile" << EOF
export SHELL="$chroot_shell"
export CHROOTCTL_CHROOT="$chroot_name"

is_chroot() {
  if [ "\${1:-}" = "status" ]; then
    if [ -n "\${CHROOTCTL_CHROOT:-}" ]; then
      echo "Inside chroot: \$CHROOTCTL_CHROOT"
    else
      echo "Not in a chroot"
    fi
  else
    if [ -n "\${CHROOTCTL_CHROOT:-}" ]; then
      return 0
    fi
    return 1
  fi
}
EOF

  if [ -n "$chroot_env" ]; then
    format_env_exports "$chroot_env" >> "$chroot_path/root/.profile"
  fi

  if [ "$chroot_user" != "none" ] && [ -n "$chroot_user" ]; then
    mkdir -p "$chroot_path/home/$chroot_user"
    cat >> "$chroot_path/home/$chroot_user/.profile" << EOF
export SHELL="$chroot_shell"
export CHROOTCTL_CHROOT="$chroot_name"

is_chroot() {
  if [ "\${1:-}" = "status" ]; then
    if [ -n "\${CHROOTCTL_CHROOT:-}" ]; then
      echo "Inside chroot: \$CHROOTCTL_CHROOT"
    else
      echo "Not in a chroot"
    fi
  else
    if [ -n "\${CHROOTCTL_CHROOT:-}" ]; then
      return 0
    fi
    return 1
  fi
}
EOF

    if [ -n "$chroot_env" ]; then
      format_env_exports "$chroot_env" >> "$chroot_path/home/$chroot_user/.profile"
    fi

    chroot "$chroot_path" chown "$chroot_user:$chroot_user" "/home/$chroot_user" "/home/$chroot_user/.profile"
  fi

  echo "$chroot_name $chroot_dir $chroot_type $chroot_shell $chroot_mount_private $chroot_mount_shared $chroot_bind_ro $chroot_bind_rw $chroot_user $chroot_version $chroot_arch" >>"$DB"

  echo "Chroot environment $chroot_name created successfully."
  echo "Enter the chroot with '$PROGRAM_NAME enter $chroot_name'."
}

show_help_create() {
  printf '%b\n' "${BOLD}${BLUE}Chrootctl create v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME create [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}-t, --type${NC}      <type>    Type of chroot environment (alpine, debian) (default: alpine)"
  printf '%b\n' "  ${GREEN}--version${NC}       <ver>     Distribution version/suite (Alpine: X.Y.Z/latest, Debian: stable/testing)"
  printf '%b\n' "  ${GREEN}--suite${NC}         <suite>   Alias for --version (Debian suite: stable, testing, etc.)"
  printf '%b\n' "  ${GREEN}--arch${NC}          <arch>    Architecture (auto-detected from uname if not specified)"
  printf '%b\n' "  ${GREEN}-d, --dir${NC}       <path>    Path to the chroot environment (default: /var/lib/chrootctl)"
  printf '%b\n' "  ${GREEN}--shell${NC}         <shell>   Default shell to use (default: /bin/sh)"
  printf '%b\n' "  ${GREEN}--mount-private${NC} <path>  Private mount point (default, [path])"
  printf '%b\n' "  ${GREEN}--mount-shared${NC}  <path>  Shared mount point"
  printf '%b\n' "  ${GREEN}--bind-ro${NC}       <src:dst> Bind mount read-only (source:destination)"
  printf '%b\n' "  ${GREEN}--bind-rw${NC}       <src:dst> Bind mount read-write (source:destination)"
  printf '%b\n' "  ${GREEN}--from${NC}          <name>  Restore chroot from local cache"
  printf '%b\n' "  ${GREEN}--user${NC}           <name>  Create a non-root user in the chroot"
  printf '%b\n' "  ${GREEN}--env${NC}            <vars>  Set environment variables (KEY=VALUE,KEY2=VALUE2)"
  printf '%b\n' "  ${GREEN}--pkg${NC}            <pkgs>  Install packages at creation time (comma-separated, e.g. curl,git)"
  printf '%b\n' "  ${GREEN}-h, --help${NC}              Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test -d /var/lib/chrootctl/test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --mount-private default${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --mount-shared /your/path${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --bind-ro ~/.claude:/home/armrib${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --bind-rw /src:/dst${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --env DEBUG=1,LOG_LEVEL=info${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME create test --pkg curl,git${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
