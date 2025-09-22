#!/bin/sh

chroot_exists() {
  [ -z "$1" ] && return 1
  local output=${2:-path}

  while IFS= read -r line; do
    local name=$(echo "$line" | awk '{print $1}')
    local dir=$(echo "$line" | awk '{print $2}')
    local type=$(echo "$line" | awk '{print $3}')
    local shell=$(echo "$line" | awk '{print $4}')
    if [ "$name" = "$1" ]; then
      case "$output" in
      path) echo "${dir}/${name}" ;;
      dir) echo "$dir" ;;
      type) echo "$type" ;;
      shell) echo "$shell" ;;
      all) echo "$line" ;;
      *) echo "$name" ;;
      esac
    fi
  done <"$DB"
}
