#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

os_type=$(get_os_type)
if [ "${os_type}" == 'ubuntu' ]
then
  runsvstart_dir="usr/sbin/runsvdir-start"
else
  runsvstart_dir="sbin/runsvdir-start"
fi

sed -i '2i rm /etc/service/monit' "${chroot}/${runsvstart_dir}"
