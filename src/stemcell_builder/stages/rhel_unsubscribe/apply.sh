#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

 run_in_chroot ${chroot} "
subscription-manager remove --all
subscription-manager unregister
"
