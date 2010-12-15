#!/bin/bash

export PATH=/var/vmc/bin:$PATH
export HOME=/root

# Shady work aroud vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
#  https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm /var/lib/apt/lists/{archive,security,lock}*
apt-get update

apt-get install -y --force-yes --no-install-recommends \
  build-essential libssl-dev openssh-server linux-headers-virtual \
  open-vm-dkms open-vm-tools monit

cd /var/vmc/bosh/src
tar zxvf ruby-1.8.7-p302.tar.gz

(
  cd ruby-1.8.7-p302
  ./configure --prefix=/var/vmc
  make && make install
)

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  /var/vmc/bin/ruby setup.rb
)

gem install bundler

version=$(cat version)
agent_path=/var/vmc/bosh/agent_${version}_builtin

mkdir -p ${agent_path}
cp -a bin lib Gemfile* vendor ${agent_path}
ln -s ${agent_path} /var/vmc/bosh/agent
chmod +x /var/vmc/bosh/agent/bin/agent

(
  cd /var/vmc/bosh/agent
  bundle install --path /var/vmc/gems
)

cp -a runit/agent /etc/sv/agent
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

echo 'export PATH=/var/vmc/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vmc/bin:$PATH' >> /home/vmc/.bashrc

cp empty_state.yml /var/vmc/bosh/state.yml
