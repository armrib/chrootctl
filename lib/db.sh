#!/bin/sh

chroot_exists() {
  [ -z "$1" ] && return 1

  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    path=$(echo "$line" | awk '{print $2}')
    if [ "$name" = "$1" ]; then
      echo "${path}/${name}"
    fi
  done <"$DB"
}
