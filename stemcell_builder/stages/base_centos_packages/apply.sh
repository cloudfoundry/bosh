#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/etc/settings.bash

case "${stemcell_operating_system_version}" in
  "6")
    init_package_name="upstart"
    version_specific_packages="nc"
    ;;
  "7")
    init_package_name="systemd"
    version_specific_packages="nmap-ncat rsyslog rsyslog-relp rsyslog-gnutls rsyslog-mmjsonparse"
    ;;
  *)
    echo "Unknown centos version: ${stemcell_operating_system_version}"
    exit 1
    ;;
esac

# The CentOS 6 script upgraded upstart first, "to prevent it from messing up our stubs and starting daemons anyway"
# so we'll upgrade systemd for possibly the same reason
pkg_mgr install ${init_package_name}

# Install base packages needed by both the warden and bosh
packages="openssl-devel lsof \
strace bind9-host dnsutils tcpdump iputils-arping \
curl wget libcurl3 libcurl3-dev bison \
readline-devel \
libxml2 libxml2-devel libxslt libxslt-devel \
dhclient \
zip unzip \
nfs-common flex psmisc apparmor-utils iptables sysstat \
rsync openssh-server traceroute libncurses5-dev quota \
libaio1 gdb libcap2-bin libcap-devel bzip2-devel \
cmake sudo libuuid-devel parted NetworkManager e2fsprogs"
pkg_mgr install ${packages} ${version_specific_packages}

# Install runit
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

# uninstall firewall so iptables are clear of any reject rules
run_in_chroot ${chroot} "yum erase -y firewalld"

# arrange for runit to start when the system boots
if [ "${init_package_name}" == "systemd" ]; then
  cp $(dirname $0)/assets/runit.service ${chroot}/usr/lib/systemd/system/
  run_in_chroot ${chroot} "systemctl enable runit"
  run_in_chroot ${chroot} "systemctl enable NetworkManager"
fi
