#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash


pkg_mgr install multipath-tools

cp -f $dir/assets/etc/multipath.conf $chroot/etc/multipath.conf

# Restart multipathd
run_in_chroot $chroot "
service multipath-tools restart
"

