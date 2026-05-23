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
}

# Clean up any stray test mounts before starting
for test_dir in /tmp/test /tmp/test-mount-combo /tmp/test-user /tmp/alpine; do
  cleanup_stray_mounts "$test_dir" || true
done

# Cleanup on exit
trap 'cleanup_stray_mounts /tmp/test; cleanup_stray_mounts /tmp/test-mount-combo; cleanup_stray_mounts /tmp/test-user; cleanup_stray_mounts /tmp/alpine' EXIT

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

./main.sh delete test-user

# Test create with environment variables
./main.sh create test-env --env DEBUG=1,LOG_LEVEL=info

# Verify env vars are in .profile
if ! grep -q 'export DEBUG="1"' /tmp/test-env/root/.profile; then
  echo "Env var test failed: DEBUG not found in .profile"
  exit 1
fi

if ! grep -q 'export LOG_LEVEL="info"' /tmp/test-env/root/.profile; then
  echo "Env var test failed: LOG_LEVEL not found in .profile"
  exit 1
fi

# Verify env vars are accessible in chroot
if ! ./main.sh exec test-env sh -c 'test "$DEBUG" = "1"'; then
  echo "Env var test failed: DEBUG not set in chroot"
  exit 1
fi

if ! ./main.sh exec test-env sh -c 'test "$LOG_LEVEL" = "info"'; then
  echo "Env var test failed: LOG_LEVEL not set in chroot"
  exit 1
fi

./main.sh delete test-env

# Test enter with temporary environment variables
./main.sh create test-temp-env

# Set temporary env vars during enter and verify they're set
if ! ./main.sh enter test-temp-env --env TEMP_VAR=temporary << 'EOF'
test "$TEMP_VAR" = "temporary" && echo "Temporary env var test passed" && exit 0
exit 1
EOF
then
  echo "Temporary env var test failed"
  exit 1
fi

./main.sh delete test-temp-env

echo "Test passed!"
