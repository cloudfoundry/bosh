#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

os_type=$(get_os_type)
if [ "${os_type}" == 'ubuntu' ]; then
  cp $dir/assets/ubuntu_dev_tools_file_list $chroot/var/vcap/bosh/etc/dev_tools_file_list
elif [ "${os_type}" == 'centos' ]; then
  cp $dir/assets/centos_dev_tools_file_list $chroot/var/vcap/bosh/etc/dev_tools_file_list
else
  touch $chroot/var/vcap/bosh/etc/dev_tools_file_list
fi
