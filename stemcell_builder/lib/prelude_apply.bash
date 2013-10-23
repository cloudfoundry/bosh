source $base_dir/lib/prelude_common.bash
source $base_dir/lib/helpers.sh

work=$1
chroot=${chroot:=$work/chroot}
mkdir -p $work $chroot

# Source settings if present
if [ -f $settings_file ]
then
  source $settings_file
fi

# Source /etc/lsb-release if present
if [ -f $chroot/etc/lsb-release ]
then
  source $chroot/etc/lsb-release
fi

function pkg_mgr {
  centos_file=$chroot/etc/centos-release
  ubuntu_file=$chroot/etc/debian_version

  if [ -f $ubuntu_file ]
  then
    echo "Found $ubuntu_file - Assuming Ubuntu"
    run_in_chroot $chroot "apt-get update"
    run_in_chroot $chroot "apt-get -f -y --force-yes --no-install-recommends $*"
    run_in_chroot $chroot "apt-get clean"
  elif [ -f $centos_file ]
  then
    echo "Found $centos_file - Assuming CentOS"
    run_in_chroot $chroot "yum update --assumeyes"
    run_in_chroot $chroot "yum --verbose --assumeyes $*"
    run_in_chroot $chroot "yum clean all"
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}
