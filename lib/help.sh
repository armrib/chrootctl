#!/bin/sh

show_help() {
  cat <<EOF
Chrootctl v${VERSION}
Usage: $PROGRAM_NAME {action} [options]
Actions:
  create                Create a chroot environment
  enter                 Enter a chroot environment
  delete                Delete a chroot environment
  help                  Show help
Examples:
  $PROGRAM_NAME create test
  $PROGRAM_NAME enter test
  $PROGRAM_NAME delete test
For more information, visit: $REPOSITORY
EOF
}

show_help_create() {
  cat <<EOF
Chrootctl v${VERSION}
Usage: $PROGRAM_NAME create [options]
Options:
  -u, --url <url>       URL of the chroot tarball
  -p, --path <path>     Path to the chroot environment
  -h, --help            Show this help message
Examples:
  $PROGRAM_NAME create test
  $PROGRAM_NAME create test -p /tmp/chroot
For more information, visit: $REPOSITORY
EOF
}
