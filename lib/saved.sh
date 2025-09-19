#!/bin/sh

list_saved() {
  echo "List of saved chroot environments:"

  for file in $CHROOT_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue
    echo "- $(basename $file)"
  done
}
