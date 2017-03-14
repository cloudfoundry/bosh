#!/bin/bash
set -xeu

chroot /tmp/ubuntu-chroot mount -t proc proc /proc
/bin/bash
