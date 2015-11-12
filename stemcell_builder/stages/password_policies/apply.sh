#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

run_in_chroot $chroot "
  find /etc/pam.d -type f -print0 | xargs -0 sed -i -r 's%\bnullok[^ ]*%%g'
"

# OS Specifics
password_file=''

if [ -f $chroot/etc/pam.d/system-auth ];then # for CentOS
  password_file=$chroot/etc/pam.d/system-auth
elif [ -f $chroot/etc/pam.d/common-password ];then  # for Ubuntu
  password_file=$chroot/etc/pam.d/common-password
fi

if [ -n "$password_file" ];then
  if [ -n "$(grep 'password.*pam_unix\.so' $password_file)" ];then
    sed -i '/password.*pam_unix\.so/s/$/ remember=24/' $password_file
  else
    echo 'password sufficient pam_unix.so remember=24' >> $password_file
  fi
fi
