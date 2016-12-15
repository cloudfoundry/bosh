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
xfsprogs gdisk libpam-cracklib"

if is_ppc64le; then
  debs="$debs \
libreadline-dev libtool texinfo ppc64-diag libffi-dev \
libruby bundler libgmp-dev libgmp3-dev libmpfr-dev libmpc-dev"
fi

pkg_mgr install $debs

function check_sha256 {
  run_in_chroot $chroot "
    cd /tmp
    echo \"${2}  ${1}\" | shasum -a 256 -c -
  "
}

function install_rsyslog_from_source {
  run_in_chroot $chroot "add-apt-repository ppa:adiscon/v8-stable"

  pkg_mgr install "libsystemd-journal-dev libestr-dev libfastjson-dev uuid-dev libgnutls-dev liblogging-stdlog-dev"

  run_in_chroot $chroot "
    cd /tmp
    wget http://download.rsyslog.com/liblogging/liblogging-1.0.5.tar.gz
    wget http://www.rsyslog.com/download/files/download/rsyslog/rsyslog-$1.tar.gz
    wget http://download.rsyslog.com/librelp/librelp-$3.tar.gz
  "

  check_sha256 liblogging-1.0.5.tar.gz 310dc1691279b7a669d383581fe4b0babdc7bf75c9b54a24e51e60428624890b
  check_sha256 rsyslog-$1.tar.gz $2
  check_sha256 librelp-$3.tar.gz $4

  run_in_chroot $chroot "
    cd /tmp
    tar xvfz liblogging-1.0.5.tar.gz
    cd liblogging-1.0.5
    ./configure --disable-man-pages --prefix=/usr
    make && sudo make install
    cd ..

    tar xvfz librelp-$3.tar.gz
    cd librelp-$3
    ./configure --prefix=/usr
    make && sudo make install
    cd ..

    tar xvfz rsyslog-$1.tar.gz
    cd rsyslog-$1
    ./configure --enable-mmjsonparse --enable-gnutls --enable-relp --prefix=/usr
    make && sudo make install

    cd /tmp
    rm -rf liblogging-* librelp-* rsyslog-*
  "
}

if ! is_ppc64le; then
  rsyslog_version=8.22.0
  rsyslog_sha256=06e2884181333dccecceaca82827ae24ca7a258b4fbf7b1e07a80d4caae640ca
  librelp_version=1.2.12
  librelp_sha256=0355730524f7b20bed1b85697296b6ce57ac593ddc8dddcdca263da71dee7bd7
  install_rsyslog_from_source $rsyslog_version $rsyslog_sha256 $librelp_version $librelp_sha256
else
  rsyslog_version=8.15.0
  rsyslog_sha256=9ed6615a8503964290471e98ed363f3975b964a34c2d4610fb815a432aadaf59
  librelp_version=1.2.9
  librelp_sha256=520de7ba3dc688dc72c5b014dc61ef191e9528f77d1651ddca55fc0c149d98a3
  install_rsyslog_from_source $rsyslog_version $rsyslog_sha256 $librelp_version $librelp_sha256
fi

exclusions="postfix whoopsie apport"
pkg_mgr purge --auto-remove $exclusions
