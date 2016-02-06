#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

pkg_mgr install wireless-crda

mkdir -p $chroot/tmp

pkg_mgr install apt-transport-https
run_in_chroot $chroot "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 363E55AB"
echo -e "\ndeb https://ealeyner:2ZHkq83hDnKsDfBLVc24@private-ppa.launchpad.net/canonical-support-eng/sf94036/ubuntu trusty main" >> $chroot/etc/apt/sources.list
pkg_mgr install linux-headers-3.19.0-49-generic=3.19.0-49.55~14.04.1hf1533043v20160201b1
pkg_mgr install linux-image-3.19.0-49-generic=3.19.0-49.55~14.04.1hf1533043v20160201b1
pkg_mgr install linux-image-extra-3.19.0-49-generic=3.19.0-49.55~14.04.1hf1533043v20160201b1
run_in_chroot $chroot "apt-key del 363E55AB"
run_in_chroot $chroot "sed -i '/launchpad/d' /etc/apt/sources.list"
