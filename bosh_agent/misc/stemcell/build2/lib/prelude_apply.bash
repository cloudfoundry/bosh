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

function apt_get {
  run_in_chroot $chroot "apt-get update"
  run_in_chroot $chroot "apt-get -f -y --force-yes --no-install-recommends $*"
  run_in_chroot $chroot "apt-get clean"
}
