#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat > $chroot/etc/apt/sources.list <<EOS
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME main universe multiverse
deb http://archive.ubuntu.com/ubuntu $DISTRIB_CODENAME-updates main universe multiverse
deb http://security.ubuntu.com/ubuntu $DISTRIB_CODENAME-security main universe multiverse
EOS

# Upgrade upstart first, to prevent it from messing up our stubs and starting daemons anyway
pkg_mgr install upstart
pkg_mgr dist-upgrade

# Install base debs needed by both the warden and bosh
debs="build-essential libssl-dev lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb tripwire libcap2-bin libcap2-dev libbz2-dev \
cmake uuid-dev libgcrypt-dev ca-certificates"
pkg_mgr install $debs

# Lifted from bosh_debs
pkg_mgr install "scsitools mg htop module-assistant debhelper runit"
#/Lifted from bosh_debs
