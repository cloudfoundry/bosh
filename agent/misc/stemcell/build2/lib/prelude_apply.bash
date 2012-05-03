source $base_dir/lib/prelude_common.bash
source $base_dir/lib/helpers.sh

work=$1
chroot=$work/chroot

mkdir -p $work $chroot

# Source any settings shipped by the stage
if [ -f $assets_dir/settings.bash ]
then
  source $assets_dir/settings.bash
fi
