#!/bin/bash

bosh_app_dir=/var/vcap

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

chown root:root ${bosh_app_dir}/bosh
chmod 0755 ${bosh_app_dir}/bosh

# Shady work around vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
# https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm /var/lib/apt/lists/{archive,security,lock}*

# add vmware package repo
apt-key add ${bosh_app_dir}/bosh/src/VMWARE-PACKAGING-GPG-KEY.pub
echo 'deb http://packages.vmware.com/tools/esx/latest/ubuntu lucid main' > /etc/apt/sources.list.d/vmware.list

# update due to above hack and the addition of vmware package repo
apt-get update

# set console data so apt-get won't try to prompt for it
debconf-set-selections <<EOT
console-data console-data/keymap/policy select Select keymap from arch list
console-data console-data/keymap/family select qwerty
console-data console-data/keymap/qwerty/layout select US american
console-data console-data/keymap/qwerty/us_american/standard/keymap select Standard
console-data console-data/keymap/qwerty/us_american/variant select Standard
EOT

# install here instead of in vmbuilder.cfg
apt-get install -y --force-yes --no-install-recommends \
  bison build-essential libssl-dev openssh-server linux-headers-virtual \
  open-vm-dkms open-vm-tools lsof strace scsitools dnsutils tcpdump tshark \
  iputils-arping curl wget libcurl4-openssl-dev libreadline5-dev libxml2 \
  libxml2-dev libxslt1.1 libxslt1-dev zip unzip git-core rsync bind9-host \
  nfs-common flex psmisc mg console-data

dpkg -l > ${bosh_app_dir}/bosh/micro_dpkg_l.out

rm -fr /var/cache/apt/archives/*deb

cd ${bosh_app_dir}/bosh/src

tar zxf monit-5.2.4.tar.gz
(
  cd monit-5.2.4
  ./configure --prefix=${bosh_app_dir}/bosh
  make && make install
)

ruby_version="1.9.2-p180"
tar jxf ruby-${ruby_version}.tar.bz2
(
  cd ruby-${ruby_version}
  ./configure \
    --prefix=${bosh_app_dir}/bosh \
    --disable-install-doc
  make && make install
)
rm -fr ruby-${ruby_version}

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

tar zxf rubygems-1.8.6.tgz
(
  cd rubygems-1.8.6
  ${bosh_app_dir}/bosh/bin/ruby setup.rb
)

gem install bundler-1.0.15.gem

mkdir -p ${bosh_app_dir}/bosh/log
chown root:root ${bosh_app_dir}/bosh
chmod 0700 ${bosh_app_dir}/bosh

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /home/vcap/.bashrc

mkdir -p ${bosh_app_dir}/bosh/etc
cp monitrc ${bosh_app_dir}/bosh/etc/monitrc
chmod 0700 ${bosh_app_dir}/bosh/etc/monitrc

# monit refuses to start without an include file present
mkdir -p ${bosh_app_dir}/monit
touch ${bosh_app_dir}/monit/empty.monitrc

cp empty_state.yml ${bosh_app_dir}/bosh/state.yml

mkdir -p ${bosh_app_dir}/shared
chown vcap:vcap ${bosh_app_dir}/shared
chmod 0700 ${bosh_app_dir}/shared

chmod 755 ${bosh_app_dir}/micro/bin/*

rm /etc/update-motd.d/*
cp motd/* /etc/update-motd.d
chmod 755 /etc/update-motd.d/*

# replace dhcp config with one that prepends the local dns server
cp dhclient.conf /etc/dhcp3
cp dnsmasq.sh /etc/dhcp3/dhclient-enter-hooks.d
cp extra.conf /etc/dnsmasq.d

# disable rpcbind which will disable statd too
sed 's/^\(start on start-portmap\)/#\1/' /etc/init/portmap.conf > \
  /etc/init/portmap.new
cat /etc/init/portmap.new > /etc/init/portmap.conf
rm /etc/init/portmap.new

# make sshd lisen to IPv4 only
echo 'ListenAddress 0.0.0.0' >> /etc/ssh/sshd_config

cp console.sh /etc/init.d
chmod 755 /etc/init.d/console.sh
ln -s /etc/init.d/console.sh /etc/rc2.d/S10console

cat > /etc/init/tty1.conf <<EOT
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]

respawn

# TODO: Ubuntu does a double exec here - figure out if it's needed
# (see /etc/init/tty2.conf on any Lucid system)
exec /sbin/getty -n -i -l /var/vcap/micro/bin/microconsole -8 38400 tty1 -8 38400 tty1
EOT
