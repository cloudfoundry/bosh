#!/bin/bash

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

version=$(cat version)
agent_path=/var/b29/bosh/agent_${version}_builtin

mkdir -p ${agent_path}
cp -a bin lib Gemfile* ${agent_path}
ln -s ${agent_path} /var/b29/bosh/agent
chmod +x /var/b29/bosh/agent/bin/agent

(
  cd /var/b29/bosh/agent
  bundle install /var/b29/gems
)

cp -a runit/agent /etc/sv/agent
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

echo 'export PATH=/var/b29/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/b29/bin:$PATH' >> /home/b29/.bashrc
