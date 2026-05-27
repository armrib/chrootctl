#!/bin/sh

create_alpine() {
  if [ -n "${1:-}" ]; then
    readonly chroot_path="$1"
  else
    echo "Missing chroot path"
    exit 1
  fi

  local version="${2:-latest}"
  local arch="${3:-}"

  if [ -z "$arch" ]; then
    arch=$(uname -m)
    case "$arch" in
      armv7l)    arch="armv7" ;;
      i686|i386) arch="x86" ;;
    esac
  fi

  local branch exact_version url

  case "$version" in
    latest|latest-stable)
      branch="latest-stable"
      ;;
    [0-9]*.[0-9]*.[0-9]*)
      branch="v$(printf '%s' "$version" | cut -d. -f1,2)"
      exact_version="$version"
      ;;
    [0-9]*.[0-9]*)
      branch="v$version"
      ;;
    *)
      echo "Unknown version format: $version"
      exit 1
      ;;
  esac

  if [ -z "${exact_version:-}" ]; then
    local yaml_url="https://dl-cdn.alpinelinux.org/alpine/${branch}/releases/${arch}/latest-releases.yaml"
    local yaml
    yaml=$(wget -q -O - "$yaml_url") || {
      echo "Failed to fetch version info from $yaml_url"
      exit 1
    }

    local filename
    filename=$(printf '%s\n' "$yaml" | grep "file: alpine-minirootfs-" | head -1 | awk '{print $2}')
    [ -z "$filename" ] && {
      echo "Could not parse latest-releases.yaml for branch $branch arch $arch"
      exit 1
    }

    exact_version=$(printf '%s' "$filename" | sed "s/alpine-minirootfs-\(.*\)-${arch}\.tar\.gz/\1/")
    local branch_resolved="v$(printf '%s' "$exact_version" | cut -d. -f1,2)"
    url="https://dl-cdn.alpinelinux.org/alpine/${branch_resolved}/releases/${arch}/${filename}"
  else
    url="https://dl-cdn.alpinelinux.org/alpine/${branch}/releases/${arch}/alpine-minirootfs-${exact_version}-${arch}.tar.gz"
  fi

  local cache_file="$DIST_CACHE_DIR/alpine-${exact_version}-${arch}.tar.gz"

  if [ ! -f "$cache_file" ]; then
    echo "Downloading Alpine ${exact_version} (${arch})"
    wget "$url" -O "$cache_file"
  fi

  tar --no-same-owner --no-same-permissions -xzf "$cache_file" -C "$chroot_path"
}
