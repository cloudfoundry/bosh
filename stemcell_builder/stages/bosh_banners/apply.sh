#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

cat << EOF > $chroot/etc/issue
Authorized uses only. All activity may be monitored and reported.
EOF

touch $chroot/etc/motd

for file in $chroot/etc/{issue,issue.net,motd}; do
    chown root:root $file
    chmod 644 $file
done