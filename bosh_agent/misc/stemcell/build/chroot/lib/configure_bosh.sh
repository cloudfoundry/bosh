#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

bosh_app_dir=/var/vcap

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

chown root:root ${bosh_app_dir}/bosh
chmod 0700 ${bosh_app_dir}/bosh

dpkg -l > ${bosh_app_dir}/bosh/stemcell_dpkg_l.out

cd ${bosh_app_dir}/bosh/src

tar zxvf monit-5.2.4.tar.gz
(
  cd monit-5.2.4
  ./configure --prefix=${bosh_app_dir}/bosh
  make -j4 && make install
)

ruby_version="1.9.2-p180"
tar jxvf ruby-${ruby_version}.tar.bz2
(
  cd ruby-${ruby_version}
  ./configure \
    --prefix=${bosh_app_dir}/bosh \
    --disable-install-doc
  make -j4 && make install
)
rm -fr ruby-${ruby_version}

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  ${bosh_app_dir}/bosh/bin/ruby setup.rb
)

gem install bundler-1.0.10.gem --no-ri --no-rdoc

version=$(cat version)
agent_path=${bosh_app_dir}/bosh/bosh_agent_${version}_builtin

mkdir -p ${agent_path}
cp -a bin lib ${agent_path}
ln -s ${agent_path} ${bosh_app_dir}/bosh/bosh_agent
chmod +x ${bosh_app_dir}/bosh/bosh_agent/bin/bosh_agent

(
  cd ${bosh_app_dir}/bosh/agent
  bundle install --path ${bosh_app_dir}/bosh/gems --without test
)

mkdir -p ${bosh_app_dir}/bosh/log
chown root:root ${bosh_app_dir}/bosh
chmod 0700 ${bosh_app_dir}/bosh

cp -a runit/agent /etc/sv/agent
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

cp sysstat /etc/default/sysstat

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

# replace vmxnet3 from included kernel
dpkg -i vmware-tools-vmxnet3-modules-source_1.0.36.0-2_amd64.deb
(
  cd /usr/src
  tar zxvf vmware-tools-vmxnet3-modules.tar.gz
  cd modules/vmware-tools-vmxnet3-modules/vmxnet3-only

  module_dir=`ls -d /lib/modules/2.6.*-virtual | tail -1`
  kernel_uname_r=`basename ${module_dir}`

  # Work around Makefile autodetection of environment - kernel version mismatch
  # as the chroot reports the host OS version
  sed "s/^VM_UNAME.*$/VM_UNAME = ${kernel_uname_r}/" Makefile > Makefile.vmxnet3_bosh

  install_dir="${module_dir}/updates/vmxnet3"
  mkdir -p $install_dir

  make -j4 -f Makefile.vmxnet3_bosh
  cp vmxnet3.ko $install_dir/
)

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /home/vcap/.bashrc

# the agent will run monit
rm /etc/init.d/monit

mkdir -p ${bosh_app_dir}/bosh/etc
cp monitrc ${bosh_app_dir}/bosh/etc/monitrc
chmod 0700 ${bosh_app_dir}/bosh/etc/monitrc

# monit refuses to start without an include file present
mkdir -p ${bosh_app_dir}/monit
touch ${bosh_app_dir}/monit/empty.monitrc

cp empty_state.yml ${bosh_app_dir}/bosh/state.yml

# TODO: We really want to lock these down - but we're having issues
# with both our components and users apps assuming this is writable
# Tempfile and friends - we'll punt on this for 4/12 and revisit it
# in the immediate release cycle after that.
# Lock dowon /tmp and /var/tmp - jobs should use /var/vcap/data/tmp
chmod 0770 /tmp /var/tmp

# remove setuid binaries - except su/sudo (sudoedit is hardlinked)
find / -xdev -perm +6000 -a -type f \
  -a -not \( -name sudo -o -name su -o -name sudoedit \) \
  -exec chmod ug-s {} \;

# the bosh agent installs a config that rotates on size
mv /etc/cron.daily/logrotate /etc/cron.hourly/logrotate

# Setup bosh specific sysctl
cp 60-bosh-sysctl.conf /etc/sysctl.d
chmod 0644 /etc/sysctl.d/60-bosh-sysctl.conf

# Clean out src
cd /var/tmp
rm -fr ${bosh_app_dir}/bosh/src
