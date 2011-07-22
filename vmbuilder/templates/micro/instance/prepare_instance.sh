#!/bin/bash

bosh_app_dir=/var/vcap

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

chown root:root ${bosh_app_dir}/bosh
chmod 0755 ${bosh_app_dir}/bosh

# Shady work aroud vmbuilder in combination with ubuntu iso cache corrupting
# the debian list caches. There is s discussion in:
#  https://bugs.launchpad.net/ubuntu/+source/update-manager/+bug/24061
rm /var/lib/apt/lists/{archive,security,lock}*
apt-get update

# install here instead of in vmbuilder.cfg
apt-get install -y --force-yes --no-install-recommends \
	bison build-essential libssl-dev openssh-server linux-headers-virtual open-vm-dkms \
	open-vm-tools lsof strace scsitools dnsutils tcpdump tshark iputils-arping curl \
	wget libcurl4-openssl-dev libreadline5-dev libxml2 libxml2-dev libxslt1.1 libxslt1-dev \
  zip unzip git-core rsync bind9-host nfs-common flex psmisc apparmor-utils mg

dpkg -l > ${bosh_app_dir}/bosh/micro_dpkg_l.out

rm -fr /var/cache/apt/archives/*deb

cd ${bosh_app_dir}/bosh/src

tar zxvf monit-5.2.4.tar.gz
(
  cd monit-5.2.4
  ./configure --prefix=${bosh_app_dir}/bosh
  make && make install
)

ruby_version="1.9.2-p180"
tar jxvf ruby-${ruby_version}.tar.bz2
(
  cd ruby-${ruby_version}
  ./configure \
    --prefix=${bosh_app_dir}/bosh \
    --disable-install-doc
  make && make install
)
rm -fr ruby-${ruby_version}

echo "gem: --no-ri --no-rdoc" > /etc/gemrc

tar zxvf rubygems-1.3.7.tgz
(
  cd rubygems-1.3.7
  ${bosh_app_dir}/bosh/bin/ruby setup.rb
)

gem install bundler-1.0.10.gem

version=$(cat version)
# agent_path=${bosh_app_dir}/bosh/agent_${version}_builtin
# 
# mkdir -p ${agent_path}
# cp -a bin lib Gemfile* vendor ${agent_path}
# ln -s ${agent_path} ${bosh_app_dir}/bosh/agent
# chmod +x ${bosh_app_dir}/bosh/agent/bin/agent
# 
# (
#   cd ${bosh_app_dir}/bosh/agent
#   bundle install --path ${bosh_app_dir}/bosh/gems
# )

mkdir -p ${bosh_app_dir}/bosh/log
chown root:root ${bosh_app_dir}/bosh
chmod 0700 ${bosh_app_dir}/bosh

# cp -a runit/agent /etc/sv/agent
# chmod +x /etc/sv/agent/run /etc/sv/agent/log/run
# ln -s /etc/sv/agent /etc/service/agent

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

# TODO: We really want to lock these down - but we're having issues
# with both our components and users apps assuming this is writable
# Tempfile and friends - we'll punt on this for 4/12 and revisit it
# in the immediate release cycle after that.
# Lock dowon /tmp and /var/tmp - jobs should use /var/vcap/data/tmp
# chmod 0770 /tmp /var/tmp

# remove setuid binaries - except su/sudo (sudoedit is hardlinked)
# find / -xdev -perm +6000 -a -type f \
#  -a -not \( -name sudo -o -name su -o -name sudoedit \) \
#  -exec chmod ug-s {} \;

mkdir -p ${bosh_app_dir}/shared
chown vcap:vcap ${bosh_app_dir}/shared
chmod 0700 ${bosh_app_dir}/shared

chmod 755 /var/vcap/micro/bin/microconsole

#
cat > /etc/init/tty1.conf <<EOT
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]

respawn

# TODO: Ubuntu does a double exec here - figure out if it's needed
# (see /etc/init/tty2.conf on any Lucid system)
exec /sbin/getty -n -i -l /var/vcap/micro/bin/microconsole -8 38400 tty1 -8 38400 tty1
EOT