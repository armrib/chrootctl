# chrootctl spec

## §G Goal

Provide a POSIX shell CLI to manage isolated chroot environments on Alpine Linux, with save/restore, mounting, and package installation—no external deps. (Arch/Debian contrib.)

## §C Constraints

**Platform & Runtime:**
- Must run as POSIX shell (sh, not bash). `set -euo pipefail` at script top.
- Requires root (chroot, mount, mknod all privileged). Auto-escalates via doas.
- Alpine Linux target; code tested on Alpine 3.22.

**Environment:**
- No external package manager calls (apk, apt, pacman) outside chroot context.
- No network access except during chroot creation (distro download).
- Distro cache @ `.cache/dist/` (dev) or `/var/cache/chrootctl/dist/` (prod).
- Chroot cache @ `.cache/chroot/` (dev) or `/var/cache/chrootctl/chroot/` (prod).
- Metadata DB @ `.db` (dev) or `/var/lib/chrootctl/db` (prod).

**Supported distros:**
- Alpine (main; built-in)
- Debian (contrib; in lib/create/debian.sh)
- Arch (contrib; in lib/create/arch.sh)

**Scope (no goal):**
- Network access inside chroot (handled by passing /etc/resolv.conf via bind-mount).
- Non-Linux chroots.
- Systemd or other init systems inside chroot.

## §V Invariants

### V1: Idempotent create
Creating a chroot with same name twice fails (name must not exist), but operations with same chroot twice succeed without error or duplicate side-effects. Reentrant commands (delete, list, save) handle missing or already-deleted chroots gracefully.

### V2: Mount isolation
Mounted filesystems (/proc, /sys, /dev, /etc/resolv.conf, custom mounts) are scoped to chroot only. No bleeding to host. Unmounting on delete removes all mounts in reverse order; stray mounts cleaned up on next delete attempt.

### V3: Metadata persists
Every created chroot records in DB: name, dir, type, shell, mount-private, mount-shared, bind-ro, bind-rw, user. Metadata restored when entering or restoring from save.

### V4: Save/restore preserves config
Saved chroot (.tar.gz + .meta) includes all mounted state and user metadata. On restore (--from), saved metadata loads as defaults; CLI parameters override (merge, don't replace).

### V5: User isolation
--user flag creates nonroot user in chroot; user owns /home/$user. Root home @ /root. No uid/gid collision with host (chroot namespaces handle this).

### V6: Environment persistence
--env vars persisted in /root/.profile and /home/$user/.profile (if user exists). Available on every enter; session-only --env in enter command adds to that session only.

### V7: Package install in context
--pkg installs packages inside chroot (not host). Works post-mount, pre-user-create, using distro's package manager (apk for Alpine, apt-get for Debian, pacman for Arch).

### V8: Bind mounts support source vars
--bind-ro and --bind-rw support $HOME and other shell vars in source path; expanded at create time. Destination always under chroot root.

### V9: Mount accumulation
--mount-private and --mount-shared (& bind flags) can be passed multiple times; all accumulate in metadata as comma-separated. On --from restore, saved mounts + new CLI mounts both applied.

### V10: Chroot detection available
Inside a running chroot, CHROOTCTL_CHROOT env var set to chroot name. is_chroot() function (in /root/.profile) returns 0 (true) inside chroot, 1 (false) outside.

### V11: No privileged ops outside root context
Mount, unmount, chroot, device binding only happen when running as root. Script auto-escalates; commands that need root refuse gracefully if doas unavailable or user denies.

### V12: Distro cache idempotence
Downloaded rootfs tarballs cached by distro name (alpine.tar.gz, debian.tar.gz, etc.). Second create reuses cache; no re-download. --from-local skips distro download, extracts saved chroot image.

### V13: Processes terminated before unmount
Before unmounting, all processes with cwd/root inside chroot are signaled SIGTERM, then SIGKILL. Prevents "busy" unmount errors. Timeout-based (wait 3s for SIGTERM, force SIGKILL).
