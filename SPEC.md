# chrootctl spec

## §G Goal

Provide a POSIX shell CLI to manage isolated chroot environments on Alpine Linux, with save/restore, mounting, and package installation—no external deps. (Arch/Debian contrib.)

## §C Constraints

**Platform & Runtime:**
- ! POSIX shell (sh, ⊥ bash). `set -euo pipefail` @ script top.
- ! root (chroot, mount, mknod privileged). Auto-escalate via doas.
- Alpine Linux target; code tested on Alpine 3.22.

**Environment:**
- ⊥ external pkg-mgr calls (apk, apt, pacman) outside chroot.
- ⊥ network except @ chroot creation (distro download).
- Distro cache @ `.cache/dist/` (dev) or `/var/cache/chrootctl/dist/` (prod).
- Chroot cache @ `.cache/chroot/` (dev) or `/var/cache/chrootctl/chroot/` (prod).
- Metadata DB @ `.db` (dev) or `/var/lib/chrootctl/db` (prod).

**Supported distros:**
- Alpine (main; built-in)
- Debian (contrib; in lib/create/debian.sh)
- Arch (contrib; in lib/create/arch.sh)

**Out of scope (⊥ goal):**
- Network @ chroot (handled via /etc/resolv.conf bind-mount).
- ⊥ Linux chroots.
- ⊥ systemd or init inside chroot.

## §V Invariants

### V1: Idempotent create
∀ create {same name 2× → fail} | {existing chroot rerun → succeed}. Reentrant ops (delete, list, save) → graceful on missing/deleted.

### V2: Mount isolation
∀ mount (proc, sys, dev, resolv.conf, custom) ⊆ chroot. ⊥ bleed → host. Delete → unmount ∀ (reverse order); stray → cleanup on next delete.

### V3: Metadata persists
∀ create → record @ DB: {name, dir, type, shell, mount-private, mount-shared, bind-ro, bind-rw, user}. Meta → restore @ enter | --from.

### V4: Save/restore preserves config
Saved {.tar.gz + .meta} ≡ ∀ mount state & user meta. --from: saved meta → defaults; CLI → merge-override (⊥ replace).

### V5: User isolation
--user → nonroot ∈ chroot; owns /home/$user. Root @ /root. ⊥ uid/gid collision (ns-isolated).

### V6: Environment persistence
--env → persist @ /root/.profile & /home/$user/.profile. ∀ enter → available; session --env → session-only add.

### V7: Package install in context
--pkg → install @ chroot (⊥ host), post-mount & pre-user-create. Uses distro pkg-mgr (apk|apt|pacman).

### V8: Bind mounts support source vars
--bind-ro|rw → expand $HOME & shell vars @ create. Dest ⊆ chroot root.

### V9: Mount accumulation
--mount-private|shared & bind flags → multi-pass accumulate @ metadata (comma-sep). --from → saved ∩ new mounts ∀ apply.

### V10: Chroot detection available
∃ running chroot → CHROOTCTL_CHROOT ≡ name. is_chroot() @ /root/.profile → 0 (true in chroot) | 1 (false out).

### V11: No privileged ops outside root context
⊥ privileged ops (mount, unmount, chroot, mknod) outside root. Auto-escalate via doas; ⊥ on unavailable | deny.

### V12: Distro cache idempotence
Rootfs .tar.gz → cache by distro (alpine|debian|…). 2× create → reuse ⊥ re-download. --from-local → extract saved.

### V13: Processes terminated before unmount
Before unmount: ∀ proc @ chroot → SIGTERM → wait 3s → SIGKILL. ∴ prevent unmount-busy.

### V14: Default mount never persisted
'default' ⊥ persisted to metadata. Internal keyword triggering auto-mount /proc, /sys, /dev.
∀ create → 'default' ∀ applied. ∀ save → strip 'default' from mount_private b4 .meta.
∀ --from restore → 'default' auto-reapplied; ! dup. (User mounts: /path1, /path2, not 'default'.)
