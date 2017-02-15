#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

# Set up users/groups
vcap_user_groups='admin,adm,audio,cdrom,dialout,floppy,video,dip,bosh_sshers'

if [ -f $chroot/etc/debian_version ] # Ubuntu
then
  vcap_user_groups+=",plugdev"
fi

run_in_chroot $chroot "
groupadd --system admin
useradd -m --comment 'BOSH System User' vcap --uid 1000
chmod 700 ~vcap
echo \"vcap:${bosh_users_password}\" | chpasswd
echo \"root:${bosh_users_password}\" | chpasswd
groupadd bosh_sshers
usermod -G ${vcap_user_groups} vcap
usermod -s /bin/bash vcap
groupadd bosh_sudoers
sed -i 's/:::/:*::/g' /etc/gshadow  # Disable users from acting as any default system group
"

# Setup SUDO
cp $assets_dir/sudoers $chroot/etc/sudoers

# Add $bosh_dir/bin to $PATH
echo "export PATH=$bosh_dir/bin:\$PATH" >> $chroot/root/.bashrc
echo "export PATH=$bosh_dir/bin:\$PATH" >> $chroot/home/vcap/.bashrc

if [ "${stemcell_operating_system}" == "centos" ] || [ "${stemcell_operating_system}" == "photonos" ] ; then
  cat > $chroot/root/.profile <<EOS
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
EOS
fi

# install custom command prompt
# due to differences in ordering between OSes, explicitly source it last
cp $assets_dir/ps1.sh $chroot/etc/profile.d/00-bosh-ps1
echo "source /etc/profile.d/00-bosh-ps1" >> $chroot/root/.bashrc
echo "source /etc/profile.d/00-bosh-ps1" >> $chroot/home/vcap/.bashrc
echo "source /etc/profile.d/00-bosh-ps1" >> $chroot/etc/skel/.bashrc
