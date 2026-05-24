# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**chrootctl** is a command-line tool written in POSIX shell for managing chroot environments on Alpine Linux. It provides a simple interface to create, enter, save, and delete isolated chroot environments with support for multiple Linux distributions (Alpine, Arch, Debian).

The tool is designed with no external dependencies and requires root access. It automatically escalates to root using `doas` when needed.

## Architecture

### High-Level Flow

1. **Entry Point** (`main.sh`): Dispatches commands to appropriate handler modules
   - Escalates to root using `doas` if needed
   - Reads environment-specific paths (development vs. production)
   - Routes commands to their handlers

2. **Command Handlers** (`lib/*.sh`): Each command has a dedicated module
   - `create.sh` — Create new chroot environments
   - `enter.sh` — Enter/interact with a chroot
   - `exec.sh` — Execute a command in a chroot without entering
   - `save.sh` — Save a chroot to cache
   - `delete.sh` — Delete a chroot
   - `list.sh`, `cache.sh`, `saved.sh` — Display information

3. **Distribution-Specific Helpers** (`lib/create/`): Bootstrapping logic per distro
   - `alpine.sh`, `arch.sh`, `debian.sh` — Distro-specific setup
   - Handles downloading/extracting rootfs, configuring base system

4. **Utilities** (`lib/utils/`): Shared functions
   - `db.sh` — Database operations (persistence of chroot metadata)
   - `mount.sh` — Mount/unmount operations
   - `abs-path.sh`, `trim.sh` — String/path utilities
   - `is-chroot.sh` — Detection utilities for checking if running in a chroot

5. **Storage**:
   - **Database** (`.db` or `/var/lib/chrootctl/db`): Metadata for created chrroots
   - **Distribution Cache** (`.cache/dist` or `/var/cache/chrootctl/dist`): Downloaded rootfs tarballs
   - **Chroot Cache** (`.cache/chroot` or `/var/cache/chrootctl/chroot`): Saved chroot images

### Key Design Decisions

- **Root Requirement**: All operations require root because chrooots involve filesystem mounts and device binding.
- **Dual Paths**: Code detects if running as `main.sh` (development) vs. installed command (production) and uses appropriate paths:
  - Dev: `.db`, `.cache/dist`, `.cache/chroot` (relative to pwd)
  - Prod: `/var/lib/chrootctl/db`, `/var/cache/chrootctl/dist/chroot`
- **POSIX Compliance**: `set -euo pipefail` ensures strict error handling; no bash-isms.
- **Distribution Abstraction**: Creation logic delegates to distro-specific scripts, making it easy to add new distributions.

## Development Commands

### Installation for Development
```sh
./install.sh
```
Installs the tool to `/opt/chrootctl` and creates a symlink to `/usr/local/bin/chrootctl`. The script will automatically escalate to root using `doas` if needed, prompting for your password if required.

### Testing
```sh
./test.sh
```
Runs integration tests that exercise all major features: create, enter, save, delete, list, cache, saved. The script will automatically escalate to root using `doas` if needed. Tests include:
- Basic operations (create, delete, list)
- Mounting/unmounting
- Saving and restoring chrroots
- Operations with custom options (e.g., `--mount-private`)

### Running Locally (Development)
```sh
./main.sh <command> [options]
```
The script will automatically escalate to root using `doas` if needed. Examples:
```sh
./main.sh create test              # Create a chroot
./main.sh enter test               # Enter a chroot
./main.sh exec test /bin/echo hi   # Run a command in a chroot
./main.sh save test                # Save a chroot
./main.sh delete test              # Delete a chroot
./main.sh list                     # List all chrroots
./main.sh cache                    # Show cached distributions
./main.sh saved                    # Show saved chrroots

# Restore from saved image with parameter overrides
./main.sh create mydev --from base-image --user alice --mount-private /src
```

### Version
```sh
./main.sh version
```

### Detecting If You're in a Chroot
When you enter a chroot with `chrootctl enter`, the environment variable `CHROOTCTL_CHROOT` is automatically set to the chroot name. You can check if you're in a chroot by sourcing the detection utility:

```sh
source lib/utils/is-chroot.sh

# Check with a return code (for conditionals)
if is_chroot; then
  echo "Inside a chroot!"
fi

# Print status
is_chroot status  # Prints "Inside chroot: <name>" or "Not in a chroot"
```

Or simply check the environment variable:
```sh
echo "$CHROOTCTL_CHROOT"  # Prints chroot name, or empty if not in one
```

## Common Development Patterns

### Restoring from Saved Images

You can create a chroot from a previously saved image using the `--from` flag. All other parameters are merged:
- Saved metadata (type, shell, user, mounts) serves as the base configuration
- Any CLI parameters override those defaults
- Mount flags accumulate (both saved and new mounts are applied)

Example workflow:
```sh
# Create and configure a base chroot
./main.sh create base -t alpine --user dev
./main.sh save base

# Restore from saved, with additional customizations
./main.sh create derived --from base --mount-private /home --pkg git,curl

# The new chroot has:
# - Alpine type and dev user from the saved image
# - Plus /home mount from the new command
```

### Adding a New Distribution
1. Create `lib/create/<distro-name>.sh` with a function like other distro scripts
2. Function should:
   - Download/extract rootfs (or use existing cache)
   - Configure base system (mount proc/sys/dev, set hostname, etc.)
   - Return successfully so chroot is mounted and usable
3. The `create.sh` dispatcher will automatically detect and call it

### Adding Database Fields
- Modify `db.sh` to add getters/setters for new fields
- Database format: space-separated fields per line, one chroot per line
- Update `list.sh`, `saved.sh` or other readers as needed

### Mounting/Unmounting Logic
- `mount.sh` contains core mount operations
- Called from `create.sh` (to mount), `enter.sh`, and `delete.sh` (to unmount)
- Handles `/proc`, `/sys`, `/dev` binding and `/etc/resolv.conf` special handling

## Code Style

- **Shebang**: `#!/bin/sh` (POSIX)
- **Error Handling**: `set -euo pipefail` at top of every script
- **Variables**: Use `readonly` for constants, quote all expansions (`"$var"`)
- **Functions**: Source required files at the top of handler functions (e.g., `source "$LIB/utils/db.sh"`)
- **Formatting**: Use colored output (defined in `install.sh`) for user-facing messages
- **Commits**: Follow emoji-based style (✨ feat, 🐛 fix, etc.)

## Important Constraints

1. **Requires root access** — The script automatically escalates to root using `doas` if not already running as root
2. **POSIX-only** — No bash extensions; must run on minimal Alpine shell
3. **No external dependencies** — Cannot rely on apk, apt, or other package managers being available
4. **Idempotent operations** — Create should handle re-runs gracefully; delete should handle missing chrroots
5. **Mount safety** — Always unmount in reverse order; handle stray mounts on error

## Testing Considerations

- Tests are integration-level (exercise full commands, not individual functions)
- Test script cleans up artifacts before running (`rm -f .cache/dist/*.tar.gz` etc.)
- Tests pipe input to commands (e.g., `echo "..." | ./main.sh enter test`)
- Run tests in a clean environment; test artifacts are ephemeral
