#!/bin/bash
set -o errexit

mkfs.ext4 -F ${1}
[ -b "${2}" ] && mknod ${2} b 7 ${3}
losetup ${2} ${1}
