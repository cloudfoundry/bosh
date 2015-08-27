#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Set up users/groups
vcap_user_groups='admin,adm,audio,cdrom,dialout,floppy,video,dip'

if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  vcap_user_groups+=",plugdev"
fi

run_in_chroot $chroot "
groupadd --system admin
useradd -m --comment 'BOSH System User' vcap
chmod 755 ~vcap
echo \"vcap:${bosh_users_password}\" | chpasswd
echo \"root:${bosh_users_password}\" | chpasswd
usermod -G ${vcap_user_groups} vcap
usermod -s /bin/bash vcap
"

# Setup SUDO
cp $assets_dir/sudoers $chroot/etc/sudoers

# Add $bosh_dir/bin to $PATH
echo "export PATH=$bosh_dir/bin:\$PATH" >> $chroot/root/.bashrc
echo "export PATH=$bosh_dir/bin:\$PATH" >> $chroot/home/vcap/.bashrc

if [ "${stemcell_operating_system}" == "centos" ] || [ "${stemcell_operating_system}" == "photon" ] ; then
  cat > $chroot/root/.profile <<EOS
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
EOS
fi
