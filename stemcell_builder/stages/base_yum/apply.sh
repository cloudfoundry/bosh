#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

packages="build-essential libssl-dev lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison libreadline6-dev \
libxml2 libxml2-dev libxslt1.1 libxslt1-dev zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb tripwire libcap2-bin libyaml-dev cmake"
# TODO: the only packages actually installed on CentOS are:
# cmake                 x86_64        2.6.4-5.el6              base        5.2 M
# openssh-server        x86_64        5.3p1-84.1.el6           base        299 k

# Install base debs needed by both the warden and bosh
pkg_mgr install $packages
