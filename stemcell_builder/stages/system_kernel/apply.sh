#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install wireless-crda

mkdir -p $chroot/tmp

pkg_mgr install linux-generic-lts-vivid
