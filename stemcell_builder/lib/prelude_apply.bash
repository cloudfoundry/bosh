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

function get_os_type {
  centos_file=$chroot/etc/centos-release
  ubuntu_file=$chroot/etc/lsb-release

  os_type=''
  if [ -f $ubuntu_file ]
  then
    os_type='ubuntu'
  elif [ -f $centos_file ]
  then
    os_type='centos'
  fi

  echo $os_type
}

function pkg_mgr {
  os_type=$(get_os_type)

  if [ "${os_type}" == 'ubuntu' ]
  then
    run_in_chroot $chroot "apt-get update"
    run_in_chroot $chroot "apt-get -f -y --force-yes --no-install-recommends $*"
    run_in_chroot $chroot "apt-get clean"
  elif [ "${os_type}" == 'centos' ]
  then
    run_in_chroot $chroot "yum update --assumeyes"
    run_in_chroot $chroot "yum --verbose --assumeyes $*"
    run_in_chroot $chroot "yum clean all"
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}
