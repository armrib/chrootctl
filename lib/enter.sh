#!/bin/sh

source "$LIB/utils/db.sh"
source "$LIB/utils/colors.sh"
source "$LIB/utils/env.sh"
source "$LIB/utils/trim.sh"

# Function to enter the chroot environment
enter_chroot() {
  if [ -n "${1:-}" ]; then
    readonly chroot_name=$1
    shift
  else
    error "Missing chroot name!"
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
  local chroot_bind_ro=$(echo "$chroot_params" | awk '{print $7}')
  local chroot_bind_rw=$(echo "$chroot_params" | awk '{print $8}')
  local chroot_user=$(echo "$chroot_params" | awk '{print $9}')
  chroot_user="${chroot_user:-none}"

  local chroot_path="${chroot_dir}/${chroot_name}"
  local chroot_shell=${chroot_shell:-/bin/sh}
  local chroot_env=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --shell)
      chroot_shell="$2"
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

  local default_mounts="/proc /dev /sys"
  [ "$chroot_type" = "arch" ] && default_mounts="/proc /dev /dev/pts /sys"
  local private_mounts=$(echo "$chroot_mount_private" | tr ',' ' ' | sed "s#default#$default_mounts#g")
  local shared_mounts=$(echo "$chroot_mount_shared" | tr ',' ' ')
  local current_mounts=$(cat /proc/mounts | cut -d' ' -f2)

  echo "Check missing private mount points..."
  for private_mount in $private_mounts; do
    if ! echo "$current_mounts" | grep -qF "${chroot_path}${private_mount}"; then
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
    if ! echo "$current_mounts" | grep -qF "${chroot_path}${shared_mount}"; then
      echo "Warn: Mount point $shared_mount is not mounted, mounting..."
      source "$LIB/utils/mount.sh"
      case "$shared_mount" in
      /*) mount_bind_shared "$shared_mount" "${chroot_path}${shared_mount}" ;;
      *) echo "Error: Invalid private mount point: $shared_mount" && exit 1 ;;
      esac
    fi
  done
  unset shared_mount

  echo "Check missing read-only bind mount points..."
  for bind_spec in $(echo "$chroot_bind_ro" | tr ',' ' ' | sed 's#none##g'); do
    [ -z "$bind_spec" ] && continue
    local bind_src=$(echo "$bind_spec" | cut -d: -f1)
    local bind_dest=$(echo "$bind_spec" | cut -d: -f2-)
    bind_src=$(eval echo "$bind_src")

    if ! echo "$current_mounts" | grep -qF "${chroot_path}${bind_dest}"; then
      echo "Warn: Bind mount $bind_dest is not mounted, mounting..."
      source "$LIB/utils/mount.sh"
      mount_bind_ro "$bind_src" "${chroot_path}${bind_dest}"
    fi
  done
  unset bind_spec bind_src bind_dest

  echo "Check missing read-write bind mount points..."
  for bind_spec in $(echo "$chroot_bind_rw" | tr ',' ' ' | sed 's#none##g'); do
    [ -z "$bind_spec" ] && continue
    local bind_src=$(echo "$bind_spec" | cut -d: -f1)
    local bind_dest=$(echo "$bind_spec" | cut -d: -f2-)
    bind_src=$(eval echo "$bind_src")

    if ! echo "$current_mounts" | grep -qF "${chroot_path}${bind_dest}"; then
      echo "Warn: Bind mount $bind_dest is not mounted, mounting..."
      source "$LIB/utils/mount.sh"
      mount_bind_rw "$bind_src" "${chroot_path}${bind_dest}"
    fi
  done
  unset bind_spec bind_src bind_dest

  echo "Entering chroot environment $chroot_name in $chroot_dir..."

  if [ "$chroot_user" != "none" ] && [ -n "$chroot_user" ]; then
    if [ -n "$chroot_env" ]; then
      chroot "$chroot_path" env $chroot_env su - "$chroot_user"
    else
      chroot "$chroot_path" su - "$chroot_user"
    fi
  else
    if [ -n "$chroot_env" ]; then
      chroot "$chroot_path" env $chroot_env su - root
    else
      chroot "$chroot_path" su - root
    fi
  fi
}

show_help_enter() {
  printf '%b\n' "${BOLD}${BLUE}Chrootctl enter v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME enter ${chroot_name:-} [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}--shell${NC} <shell>       Default shell to use (default: /bin/sh)"
  printf '%b\n' "  ${GREEN}--env${NC}  <vars>         Set environment variables for this session (KEY=VALUE,KEY2=VALUE2)"
  printf '%b\n' "  ${GREEN}-h, --help${NC}            Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME enter test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME enter test --shell /bin/bash${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME enter test --env DEBUG=1${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
