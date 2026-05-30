#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

# Escalate to root with doas if not already running as root
if [ "$(id -u)" -ne 0 ]; then
  exec doas "$0" "$@"
fi

# Cleanup stray mounts from previous test runs
cleanup_stray_mounts() {
  local chroot_path="$1"
  if [ -d "$chroot_path" ]; then
    local all_mounts=$(mount | grep "^[^ ]* on ${chroot_path}" | awk '{print $3}' | sort -r || true)
    for mount_point in $all_mounts; do
      if mountpoint -q "$mount_point" 2>/dev/null; then
        echo "Cleaning up stray mount: $mount_point"
        umount -fn "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
      fi
    done
  fi

  # Also remove from database if it exists
  local chroot_name=$(basename "$chroot_path")
  if [ -f ".db" ]; then
    sed -i "/^${chroot_name} /d" ".db" 2>/dev/null || true
  fi
}

# Clean up any stray test mounts before starting (both /tmp and default /var/lib/chrootctl)
for test_dir in /var/lib/chrootctl/test /var/lib/chrootctl/test-mount-combo /var/lib/chrootctl/test-user /var/lib/chrootctl/test-env /var/lib/chrootctl/test-pkg /var/lib/chrootctl/test-is-chroot /var/lib/chrootctl/test-temp-env /tmp/test /tmp/test-mount-combo /tmp/test-user /tmp/alpine; do
  cleanup_stray_mounts "$test_dir" || true
done

# Cleanup on exit
trap 'for d in /var/lib/chrootctl/test /var/lib/chrootctl/test-mount-combo /var/lib/chrootctl/test-user /var/lib/chrootctl/test-env /var/lib/chrootctl/test-pkg /var/lib/chrootctl/test-is-chroot /var/lib/chrootctl/test-temp-env /tmp/test /tmp/test-mount-combo /tmp/test-user /tmp/alpine; do cleanup_stray_mounts "$d"; done' EXIT

for file in .cache/dist/alpine.tar.gz .cache/chroot/test.tar.gz; do
  rm -f "$file"
done
unset file

./main.sh list

./main.sh cache

./main.sh saved

./main.sh create test

echo "echo; echo 'I am running in the chroot environment!'; echo; exit 0" | ./main.sh enter test

./main.sh delete test

./main.sh list

./main.sh cache

./main.sh saved

./main.sh create test --mount-private /etc/resolv.conf

echo "apk update && apk upgrade; exit 0" | ./main.sh enter test

./main.sh save test

./main.sh delete test

./main.sh list

./main.sh cache

./main.sh saved

# Test delete with both mount-private and mount-shared
./main.sh create test-mount-combo --mount-private /etc/resolv.conf --mount-shared /tmp

echo "exit 0" | ./main.sh enter test-mount-combo

./main.sh delete test-mount-combo

# Test create with user
./main.sh create test-user --user testuser

# Verify user was created (check if home directory exists)
if ! ./main.sh exec test-user test -d /home/testuser; then
  echo "User verification failed: testuser home directory not found"
  exit 1
fi

# Verify user owns their home directory
if ! ./main.sh exec test-user test -O /home/testuser; then
  echo "User ownership test failed: testuser does not own /home/testuser"
  exit 1
fi

./main.sh delete test-user

# Test create with environment variables
./main.sh create test-env --env DEBUG=1,LOG_LEVEL=info

# Verify env vars are in .profile
if ! grep -q 'export DEBUG="1"' /var/lib/chrootctl/test-env/root/.profile; then
  echo "Env var test failed: DEBUG not found in .profile"
  exit 1
fi

if ! grep -q 'export LOG_LEVEL="info"' /var/lib/chrootctl/test-env/root/.profile; then
  echo "Env var test failed: LOG_LEVEL not found in .profile"
  exit 1
fi

# Verify env vars are accessible in chroot (using enter which sources .profile)
if ! echo 'test "$DEBUG" = "1" && test "$LOG_LEVEL" = "info" && exit 0; exit 1' | ./main.sh enter test-env; then
  echo "Env var test failed: env vars not accessible in chroot"
  exit 1
fi

./main.sh delete test-env

# Test enter with temporary environment variables
./main.sh create test-temp-env

# Set temporary env vars during enter and verify they're set
echo 'echo "TEMP_VAR is: $TEMP_VAR"; [ "$TEMP_VAR" = "temporary" ] && exit 0; exit 1' | ./main.sh enter test-temp-env --env TEMP_VAR=temporary

./main.sh delete test-temp-env

# Test create with packages
./main.sh create test-pkg --pkg curl,git

# Verify packages were installed (check if executables exist)
if ! ./main.sh exec test-pkg test -f /usr/bin/curl; then
  echo "Package test failed: curl not found in /usr/bin"
  exit 1
fi

if ! ./main.sh exec test-pkg test -f /usr/bin/git; then
  echo "Package test failed: git not found in /usr/bin"
  exit 1
fi

./main.sh delete test-pkg

# Test is_chroot function
./main.sh create test-is-chroot

# Verify is_chroot returns 0 (true) when inside chroot
if ! echo 'is_chroot && exit 0; exit 1' | ./main.sh enter test-is-chroot; then
  echo "is_chroot test failed: function returned false inside chroot"
  exit 1
fi

# Verify is_chroot status prints the correct message
if ! echo 'is_chroot status' | ./main.sh enter test-is-chroot | grep -q "Inside chroot: test-is-chroot"; then
  echo "is_chroot status test failed: incorrect output"
  exit 1
fi

./main.sh delete test-is-chroot

# Test exec with shell syntax (single argument)
./main.sh create test-exec

# Verify shell syntax works with && operator
if ! ./main.sh exec test-exec "echo first && echo second" | grep -q "first"; then
  echo "Exec shell syntax test failed: first output not found"
  exit 1
fi

if ! ./main.sh exec test-exec "echo first && echo second" | grep -q "second"; then
  echo "Exec shell syntax test failed: second output not found"
  exit 1
fi

# Verify env vars are accessible in exec with shell syntax
if ! ./main.sh exec test-exec --env TEST_VAR=testvalue 'echo "$TEST_VAR"' | grep -q "testvalue"; then
  echo "Exec env var test failed: TEST_VAR not accessible"
  exit 1
fi

# Verify /etc/profile is sourced (CHROOTCTL_CHROOT should be set)
if ! ./main.sh exec test-exec 'test -n "$CHROOTCTL_CHROOT"' 2>/dev/null; then
  echo "Exec profile sourcing test failed: CHROOTCTL_CHROOT not set"
  exit 1
fi

./main.sh delete test-exec

echo "Test passed!"
