#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

for file in .cache/dist/alpine.tar.gz .cache/chroot/test.tar.gz; do
  rm -f "$file"
done
unset file

./main.sh list

./main.sh cache

./main.sh saved

./main.sh create test

echo "echo; echo 'I am running in the chroot environment!'; echo; exit 0" | ./main.sh enter test

./main.sh delete test

./main.sh list

./main.sh cache

./main.sh saved

./main.sh create test --mount-private /etc/resolv.conf

echo "apk update && apk upgrade; exit 0" | ./main.sh enter test

./main.sh save test

./main.sh delete test

./main.sh list

./main.sh cache

./main.sh saved

echo "Test passed!"
