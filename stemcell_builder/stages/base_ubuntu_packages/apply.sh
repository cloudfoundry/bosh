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
cloud-guest-utils anacron software-properties-common \
xfsprogs"

if is_ppc64le; then
  debs="$debs \
libreadline-dev libtool texinfo ppc64-diag libffi-dev \
libruby bundler libgmp-dev libgmp3-dev libmpfr-dev libmpc-dev"
fi

pkg_mgr install $debs

if ! is_ppc64le; then
  # we need newer rsyslog; this comes from the upstream project's own repo
  run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"
  # needed to remove rsyslog-mmjsonparse on ppc64le
  # because of this issue https://gist.github.com/allomov-altoros/cd579aa76f3049bee9c7
  pkg_mgr install "rsyslog rsyslog-relp rsyslog-gnutls"
  pkg_mgr install "rsyslog-mmjsonparse"
else
  # on ppc64le compile from source as the .deb packages are not available 
  # from the repo above
  wget http://download.rsyslog.com/liblogging/liblogging-1.0.5.tar.gz
  wget http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-8.15.0.tar.gz
  wget http://download.rsyslog.com/librelp/librelp-1.2.9.tar.gz
  
  pkg_mgr install "libsystemd-journal-dev libestr-dev libjson0 libjson0-dev uuid-dev python-docutils libcurl4-openssl-dev" 

  tar xvfz liblogging-1.0.5.tar.gz 
  cd liblogging-1.0.5
  ./configure --disable-man-pages
  make && sudo make install
  cd ..
  
  tar xvfz librelp-1.2.9.tar.gz
  cd librelp-1.2.9
  ./configure
  make && sudo make install
  cd ..

  tar xvfz rsyslog-8.15.0.tar.gz
  cd rsyslog-8.15.0
  ./configure --enable-mmjsonparse --enable-gnutls --enable-relp
  make && make install
  cd ..

fi


exclusions="postfix"
pkg_mgr purge --auto-remove $exclusions
