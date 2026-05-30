#!/bin/sh

source "$LIB/utils/db.sh"
source "$LIB/utils/colors.sh"

save_chroot() {
  if [ -n "${1:-}" ]; then
    readonly chroot_name=$1
    shift
  else
    echo "Missing chroot name"
    show_help_save
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
  local chroot_version=$(echo "$chroot_params" | awk '{print $10}')
  local chroot_arch=$(echo "$chroot_params" | awk '{print $11}')

  local chroot_path="${chroot_dir}/${chroot_name}"
  local save_chroot_name="$chroot_name"
  local force=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
    -n | --name)
      save_chroot_name="$2"
      shift 2
      ;;
    -f | --force)
      force=true
      shift
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

  echo "Saving $save_chroot_name chroot environment..."
  for file in $CHROOT_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] && [ "$force" = "false" ] && [ "$file" = "$CHROOT_CACHE_DIR/${save_chroot_name}.tar.gz" ] && echo "Error: Artefact $save_chroot_name already exists." && exit 1
  done
  unset file

  source "$LIB/delete.sh"
  # Kill all chroot processes
  wait_and_kill_all_chroot_process "$chroot_path"

  source "$LIB/utils/mount.sh"
  # Unmount all filesystems under the chroot
  unmount_chroot "$chroot_path"

  # Compress the chroot
  (cd "$chroot_path" && tar -czf "$CHROOT_CACHE_DIR/${save_chroot_name}.tar.gz" .)

  # Save metadata for restoration without mounts—restored chroots start fresh with defaults only
  echo "$save_chroot_name $chroot_dir $chroot_type $chroot_shell none none none none $chroot_user $chroot_version $chroot_arch" >"$CHROOT_CACHE_DIR/${save_chroot_name}.meta"

  echo "Chroot environment $save_chroot_name saved!"

  # Re-mount the chroot so it remains usable after saving
  mount_proc "$chroot_path"
  mount_bind_private /dev "$chroot_path/dev"
  mount_bind_private /sys "$chroot_path/sys"
  if [ "$chroot_type" = "arch" ]; then
    mount_bind_private /dev/pts "$chroot_path/dev/pts"
  fi

  # Re-mount custom mounts from database
  if [ "$chroot_mount_private" != "none" ] && [ -n "$chroot_mount_private" ]; then
    for mount_private in $(echo "$chroot_mount_private" | tr ',' ' '); do
      [ -n "$mount_private" ] && [ "$mount_private" != "default" ] && mount_bind_private "$mount_private" "${chroot_path}${mount_private}"
    done
  fi

  if [ "$chroot_mount_shared" != "none" ] && [ -n "$chroot_mount_shared" ]; then
    for mount_shared in $(echo "$chroot_mount_shared" | tr ',' ' '); do
      [ -n "$mount_shared" ] && mount_bind_shared "$mount_shared" "${chroot_path}${mount_shared}"
    done
  fi

  if [ "$chroot_bind_ro" != "none" ] && [ -n "$chroot_bind_ro" ]; then
    for bind_spec in $(echo "$chroot_bind_ro" | tr ',' ' '); do
      [ -n "$bind_spec" ] && {
        src=$(echo "$bind_spec" | cut -d: -f1)
        dest=$(echo "$bind_spec" | cut -d: -f2-)
        src=$(eval echo "$src")
        [ -e "$src" ] && mount_bind_ro "$src" "${chroot_path}${dest}"
      }
    done
  fi

  if [ "$chroot_bind_rw" != "none" ] && [ -n "$chroot_bind_rw" ]; then
    for bind_spec in $(echo "$chroot_bind_rw" | tr ',' ' '); do
      [ -n "$bind_spec" ] && {
        src=$(echo "$bind_spec" | cut -d: -f1)
        dest=$(echo "$bind_spec" | cut -d: -f2-)
        src=$(eval echo "$src")
        [ -e "$src" ] && mount_bind_rw "$src" "${chroot_path}${dest}"
      }
    done
  fi

  echo "You can now delete the chroot with 'chrootctl delete $save_chroot_name'."
  echo "To restore the chroot, run 'chrootctl create $save_chroot_name --from $save_chroot_name'."
}

show_help_save() {
  printf '%b\n' "${BOLD}${BLUE}Chrootctl save v${VERSION}${NC}"
  printf '%b\n' "${BOLD}${CYAN}Usage:${NC} $PROGRAM_NAME save ${chroot_name:-} [options]"
  printf '%b\n' "${BOLD}${CYAN}Options:${NC}"
  printf '%b\n' "  ${GREEN}-n, --name${NC}            Name of the saved chroot environment"
  printf '%b\n' "  ${GREEN}-h, --help${NC}            Show this help message"
  printf '%b\n' "${BOLD}${CYAN}Examples:${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME save test${NC}"
  printf '%b\n' "  ${YELLOW}$PROGRAM_NAME save test -n package-testing${NC}"
  printf '%b\n' "${BOLD}${CYAN}For more information, visit:${NC} $REPOSITORY"
}
