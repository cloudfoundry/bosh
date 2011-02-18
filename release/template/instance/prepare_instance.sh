#!/bin/bash

bosh_app_dir=/var/vcap

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

RUBY_VERSION=1.8.7-p302
RUBYGEMS_VERSION=1.5.2
CHEF_VERSION=0.9.12

# Shady work around vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
#  https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm /var/lib/apt/lists/{archive,security,lock}*
apt-get update

apt-get install -y --force-yes --no-install-recommends \
  build-essential libssl-dev openssh-server linux-headers-virtual \
  open-vm-dkms open-vm-tools lsof strace scsitools dnsutils \
  tcpdump tshark iputils-arping curl wget libcurl3 libcurl3-dev \
  bison libreadline5-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev \
  zip unzip git-core

dpkg -l > ${bosh_app_dir}/bosh/dpkg_l.out

cd /tmp
wget ftp://ftp.ruby-lang.org/pub/ruby/1.8/ruby-$RUBY_VERSION.tar.gz
tar zxvf ruby-$RUBY_VERSION.tar.gz
(
  cd ruby-$RUBY_VERSION
  ./configure \
    --disable-pthread \
    --prefix=${bosh_app_dir}/bosh
  make && make install
)

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

wget http://production.cf.rubygems.org/rubygems/rubygems-$RUBYGEMS_VERSION.tgz
tar zxvf rubygems-$RUBYGEMS_VERSION.tgz
(
  cd rubygems-$RUBYGEMS_VERSION
  ${bosh_app_dir}/bosh/bin/ruby setup.rb
)

gem install chef --version $CHEF_VERSION

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

mkdir -p /var/vcap/deploy /var/vcap/storage
chown vcap:vcap /var/vcap/deploy /var/vcap/storage

echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /home/vcap/.bashrc
