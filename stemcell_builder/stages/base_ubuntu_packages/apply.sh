#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

debs="libssl-dev lsof strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap2-dev libbz2-dev \
cmake uuid-dev libgcrypt-dev ca-certificates \
scsitools mg htop module-assistant debhelper runit parted \
anacron software-properties-common"
pkg_mgr install $debs

# we need newer rsyslog; this comes from the upstream project's own repo
run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"
pkg_mgr install "rsyslog rsyslog-relp rsyslog-mmjsonparse rsyslog-gnutls"

exclusions="postfix"
pkg_mgr purge --auto-remove $exclusions
