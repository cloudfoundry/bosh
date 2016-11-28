bosh_app_dir=/var/vcap
bosh_dir=$bosh_app_dir/bosh

mkdir -p $chroot/$bosh_dir
chown root:root $chroot/$bosh_dir
chmod 0700 $chroot/$bosh_dir

mkdir -p $chroot/$bosh_dir/log

function run_in_bosh_chroot {
  local chroot=$1
  local script=$2

  run_in_chroot $chroot "
    export PATH=$bosh_dir/bin:\$PATH
    export HOME=/root

    cd $bosh_dir

    $script
  "
}
