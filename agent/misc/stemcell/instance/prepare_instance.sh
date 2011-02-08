#!/bin/bash

export PATH=/var/vmc/bosh/bin:$PATH
export HOME=/root

# Shady work aroud vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
#  https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm /var/lib/apt/lists/{archive,security,lock}*
apt-get update

apt-get install -y --force-yes --no-install-recommends \
  build-essential libssl-dev openssh-server linux-headers-virtual \
  open-vm-dkms open-vm-tools monit lsof strace scsitools bind9-host \
  dnsutils tcpdump tshark iputils-arping curl wget libcurl3 libcurl3-dev \
  bison libreadline5-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev \
  zip unzip

cd /var/vmc/bosh/src
tar zxvf ruby-1.8.7-p302.tar.gz

(
  cd ruby-1.8.7-p302
  ./configure \
    --disable-pthread \
    --prefix=/var/vmc/bosh
  make && make install
)

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  /var/vmc/bosh/bin/ruby setup.rb
)

gem install bundler-1.0.7.gem

version=$(cat version)
agent_path=/var/vmc/bosh/agent_${version}_builtin

mkdir -p ${agent_path}
cp -a bin lib Gemfile* vendor ${agent_path}
ln -s ${agent_path} /var/vmc/bosh/agent
chmod +x /var/vmc/bosh/agent/bin/agent

(
  cd /var/vmc/bosh/agent
  bundle install --path /var/vmc/bosh/gems
)

cp -a runit/agent /etc/sv/agent
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

echo 'export PATH=/var/vmc/bosh/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vmc/bosh/bin:$PATH' >> /home/vmc/.bashrc

echo -e "startup=1\n" > /etc/default/monit
mkidr -p /var/vmc/monit
cp monitrc /etc/monit/monitrc

#echo -e "set daemon 10\nset logfile /var/vmc/monit/monit.log\ninclude /var/vmc/monit/*.monitrc\n" > /etc/monit/monitrc

# monit refuses to start without an include file present
mkdir -p /var/vmc/monit
touch /var/vmc/monit/empty.monitrc

mkdir -p /var/vmc/sys/run

cp empty_state.yml /var/vmc/bosh/state.yml
