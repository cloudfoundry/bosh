#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ "$(get_os_type)" == "centos" ]; then
  sudoers_group="wheel"
elif [ "$(get_os_type)" == "ubuntu" ]; then
  sudoers_group="sudo"
fi
# restrict Access to the su Command add the following line to the /etc/pam.d/su file.
# auth required pam_wheel.so use_uid add vcap user to 'root' group
run_in_chroot $chroot "
  sudo echo 'auth required pam_wheel.so use_uid' >> /etc/pam.d/su
  sudo usermod -aG ${sudoers_group} vcap
"
