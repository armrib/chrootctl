#!/bin/sh

list_cache() {
  echo "List of cached distributions:"

  for file in $DIST_CACHE_DIR/*.tar.gz; do
    [ -f "$file" ] || continue
    echo "- $(basename $file)"
  done
  unset file
}
