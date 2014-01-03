#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Upgrade upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install upstart

# Install base packages needed by both the warden and bosh
packages="build-essential openssl-devel lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison \
readline-devel \
libxml2 libxml2-devel libxslt libxslt-devel \
dhclient \
zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap-devel bzip2-devel \
libyaml-devel cmake sudo nc libuuid-devel"
pkg_mgr install $packages

# Lifted from bosh_debs
#pkg_mgr install "scsitools mg htop module-assistant debhelper"
#/Lifted from bosh_debs

# runit
pkg_mgr install "rpm-build rpmdevtools glibc-static"
cookbook_release=1.2.0
runit_version=runit-2.1.1
run_in_chroot $chroot "
  curl -L https://github.com/opscode-cookbooks/runit/archive/v${cookbook_release}.tar.gz > /tmp/v${cookbook_release}.tar.gz
  tar -C /tmp -xvf /tmp/v${cookbook_release}.tar.gz
  tar -C /tmp -xvf /tmp/runit-${cookbook_release}/files/default/${runit_version}.tar.gz
  cd /tmp/${runit_version}
  ./build.sh
  rpm -i /rpmbuild/RPMS/${runit_version}.rpm
"
#/runit
