#!/bin/sh

# Check if currently running inside a chrootctl-managed chroot
# Returns 0 (true) if in chroot, 1 (false) otherwise
# Call with argument to print status: is_chroot status
is_chroot() {
  if [ "${1:-}" = "status" ]; then
    if [ -n "${CHROOTCTL_CHROOT:-}" ]; then
      echo "Inside chroot: $CHROOTCTL_CHROOT"
    else
      echo "Not in a chroot"
    fi
  else
    if [ -n "${CHROOTCTL_CHROOT:-}" ]; then
      return 0
    fi
    return 1
  fi
}
