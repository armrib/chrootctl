#!/bin/sh

source "$LIB/db.sh"

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
  chroot_params=$(chroot_exists "$chroot_name" all)
  if [ -z "$chroot_params" ]; then
    echo "Chroot environment $chroot_name does not exist."
    exit 1
  fi

  chroot_dir=$(echo "$chroot_params" | awk '{print $2}')
  chroot_type=$(echo "$chroot_params" | awk '{print $3}')
  chroot_shell=$(echo "$chroot_params" | awk '{print $4}')
  chroot_mount_ro=$(echo "$chroot_params" | awk '{print $5}')
  chroot_mount_rw=$(echo "$chroot_params" | awk '{print $6}')

  chroot_path="${chroot_dir}/${chroot_name}"
  save_chroot_name="$chroot_name"
  force=false

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

  source "$LIB/delete.sh"

  # Kill all chroot processes
  wait_and_kill_all_chroot_process "$chroot_path"

  # Unmount all filesystems under the chroot
  unmount_chroot "$chroot_path"

  # Compress the chroot
  (cd "$chroot_path" && tar -czf "$CHROOT_CACHE_DIR/${save_chroot_name}.tar.gz" .)
  echo "Chroot environment $save_chroot_name saved!"
  echo "You can now delete the chroot with 'chrootctl delete $save_chroot_name'."
  echo "To restore the chroot, run 'chrootctl create $save_chroot_name --from-local $save_chroot_name'."
}

show_help_save() {
  cat <<EOF
Chrootctl save v${VERSION}
Usage: $PROGRAM_NAME save ${chroot_name:-} [options]
Options:
  -n, --name            Name of the saved chroot environment
  -h, --help            Show this help message
Examples:
  $PROGRAM_NAME save test
  $PROGRAM_NAME save test -n package-testing
For more information, visit: $REPOSITORY
EOF
}
