#!/bin/sh

chroot_exists() {
  [ -z "$1" ] && return 1
  output=${2:-path}

  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    dir=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')
    shell=$(echo "$line" | awk '{print $4}')
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
