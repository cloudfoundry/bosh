#!/bin/bash

bosh_app_dir=/var/vcap

export PATH=${bosh_app_dir}/bosh/bin:$PATH
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
  zip unzip nfs-common

dpkg -l > ${bosh_app_dir}/bosh/stemcell_dpkg_l.out

cd ${bosh_app_dir}/bosh/src
tar zxvf ruby-1.8.7-p302.tar.gz

(
  cd ruby-1.8.7-p302
  ./configure \
    --disable-pthread \
    --prefix=${bosh_app_dir}/bosh
  make && make install
)

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  ${bosh_app_dir}/bosh/bin/ruby setup.rb
)

gem install bundler-1.0.7.gem

version=$(cat version)
agent_path=${bosh_app_dir}/bosh/agent_${version}_builtin

mkdir -p ${agent_path}
cp -a bin lib Gemfile* vendor ${agent_path}
ln -s ${agent_path} ${bosh_app_dir}/bosh/agent
chmod +x ${bosh_app_dir}/bosh/agent/bin/agent

(
  cd ${bosh_app_dir}/bosh/agent
  bundle install --path ${bosh_app_dir}/bosh/gems
)

cp -a runit/agent /etc/sv/agent
chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
ln -s /etc/sv/agent /etc/service/agent

ln -s /etc/init.d/open-vm-tools /etc/rc2.d/S88open-vm-tools

# vmbuilder will default to dhcp when no IP is specified - wipe
echo -e "auto lo\niface lo inet loopback\n" > /etc/network/interfaces

echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /root/.bashrc
echo 'export PATH=/var/vcap/bosh/bin:$PATH' >> /home/vcap/.bashrc

echo -e "startup=1\n" > /etc/default/monit
mkidr -p ${bosh_app_dir}/monit
cp monitrc /etc/monit/monitrc

# monit refuses to start without an include file present
mkdir -p ${bosh_app_dir}/monit
touch ${bosh_app_dir}/monit/empty.monitrc

mkdir -p ${bosh_app_dir}/sys/run

cp empty_state.yml ${bosh_app_dir}/bosh/state.yml
