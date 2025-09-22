#!/bin/sh

trim() {
  # Usage: trim_string "   example   string    "

  # Remove all leading white-space.
  # '${1%%[![:space:]]*}': Strip everything but leading white-space.
  # '${1#${XXX}}': Remove the white-space from the start of the string.
  local trim=${1#${1%%[![:space:]]*}}

  # Remove all trailing white-space.
  # '${trim##*[![:space:]]}': Strip everything but trailing white-space.
  # '${trim%${XXX}}': Remove the white-space from the end of the string.
  trim=${trim%${trim##*[![:space:]]}}

  printf '%s\n' "$trim"
}

# shellcheck disable=SC2086,SC2048
trim_all() {
  # Usage: trim_all "   example   string    "

  # Disable globbing to make the word-splitting below safe.
  set -f

  # Set the argument list to the word-splitted string.
  # This removes all leading/trailing white-space and reduces
  # all instances of multiple spaces to a single ("  " -> " ").
  set -- $*

  # Print the argument list as a string.
  printf '%s\n' "$*"

  # Re-enable globbing.
  set +f
}
