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
  rhel_file=$chroot/etc/redhat-release
  ubuntu_file=$chroot/etc/lsb-release
  photon_file=$chroot/etc/photon-release

  os_type=''
  if [ -f $photon_file ]
  then
    os_type='photon'
  elif [ -f $ubuntu_file ]
  then
    os_type='ubuntu'
  elif [ -f $centos_file ]
  then
    os_type='centos'
  elif [ -f $rhel_file ]
  then
    os_type='rhel'
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
  elif [ "${os_type}" == 'centos' -o "${os_type}" == 'rhel' -o "${os_type}" == 'photon' ]
  then
    run_in_chroot $chroot "yum update --assumeyes"
    run_in_chroot $chroot "yum --verbose --assumeyes $*"
    run_in_chroot $chroot "yum clean all"
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}

# checks if an OS package with the given name exists in the current database of available packages.
# returns 0 if package exists (whether or not is is installed); 1 otherwise
function pkg_exists {
  os_type=$(get_os_type)

  if [ "${os_type}" == 'ubuntu' ]
  then
    run_in_chroot $chroot "apt-get update"
    result=`run_in_chroot $chroot "if apt-cache show $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
    if [ "$result" == 'exists' ]; then
      return 0
    else
      return 1
    fi
  elif [ "${os_type}" == 'centos' -o "${os_type}" == 'rhel' -o "${os_type}" == 'photon' ]
  then
    result=`run_in_chroot $chroot "if yum list $1 2>/dev/null >/dev/null; then echo exists; else echo does not exist; fi"`
    if [ "$result" == 'exists' ]; then
      return 0
    else
      return 1
    fi
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}
