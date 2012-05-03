#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

debs="build-essential libssl-dev lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline5-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute"

# Disable interactive dpkg
debconf="debconf debconf/frontend select noninteractive"
run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"

# Networking...
cp $assets_dir/etc/hosts $chroot/etc/hosts

# Timezone
cp $assets_dir/etc/timezone $chroot/etc/timezone
run_in_chroot $chroot "dpkg-reconfigure -fnoninteractive -pcritical tzdata"

# Locale
cp $assets_dir/etc/default/locale $chroot/etc/default/locale
run_in_chroot $chroot "
locale-gen en_US.UTF-8
dpkg-reconfigure -fnoninteractive -pcritical libc6
dpkg-reconfigure -fnoninteractive -pcritical locales
"

# Firstboot script
cp $assets_dir/etc/rc.local $chroot/etc/rc.local
cp $assets_dir/root/firstboot.sh $chroot/root/firstboot.sh
chmod 0755 $chroot/root/firstboot.sh

# Update apt
cp $assets_dir/etc/apt/sources.list $chroot/etc/apt/sources.list

run_in_chroot $chroot "apt-get update"

# Upgrade upstart first, to prevent it from messing up our stubs and starting daemons anyway
run_in_chroot $chroot "apt-get -y --force-yes install upstart"

# Upgrade
run_in_chroot $chroot "apt-get -y --force-yes dist-upgrade"

# Install base debs needed by both the warden and bosh
run_in_chroot $chroot "apt-get install -y --force-yes --no-install-recommends $debs"

# Woo, done. Clean up.
run_in_chroot $chroot "apt-get clean"
