#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

run_in_chroot $chroot "
  find /etc/pam.d -type f -print0 | xargs -0 sed -i -r 's%\bnullok[^ ]*%%g'
"
