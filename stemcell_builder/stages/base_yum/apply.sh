#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash


# Upgrade upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install upstart

# Install base packages needed by both the warden and bosh
packages="build-essential openssl-devel lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-devel libxslt libxslt-devel \
dhclient \
zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb tripwire libcap2-bin libyaml-devel cmake"
pkg_mgr install $packages

# Lifted from bosh_debs
#pkg_mgr install "scsitools mg htop module-assistant debhelper"
#/Lifted from bosh_debs

# runit
pkg_mgr install "rpm-build rpmdevtools glibc-static"
runit_version=runit-2.1.1
run_in_chroot $chroot "
  curl -L https://github.com/opscode-cookbooks/runit/blob/master/files/default/${runit_version}.tar.gz?raw=true > /tmp/${runit_version}.tar.gz
  tar -C /tmp -xvf /tmp/${runit_version}.tar.gz
  cd /tmp/${runit_version}
  ./build.sh
  rpm -i /rpmbuild/RPMS/${runit_version}.rpm
"
#/runit
