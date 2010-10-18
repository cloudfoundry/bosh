#!/bin/sh

export PATH=/var/b29/bin:$PATH
export HOME=/root

apt-get install -y --force-yes --no-install-recommends \
  build-essential openssh-server linux-headers-virtual \
  open-vm-dkms open-vm-tools monit

cd /var/b29/bosh/src
tar zxvf ruby-1.8.7-p302.tar.gz

(
  cd ruby-1.8.7-p302
  ./configure --prefix=/var/b29 
  make && make install
)

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  /var/b29/bin/ruby setup.rb
)

gem install bundler

mkdir -p /var/b29/bosh/agent
cp -a lib Gemfile* /var/b29/bosh/agent/

(
  cd /var/b29/bosh/agent
  bundle install /var/b29/share/gems
)

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces
