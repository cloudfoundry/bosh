set -e # errexit
set -u # nounset

dir=$(dirname $0)
assets_dir=$dir/assets
base_dir=$(readlink -nf $dir/../..)
lib_dir=$(readlink -nf $base_dir/lib)
skeleton_dir=$(readlink -nf $base_dir/skeleton)

source $lib_dir/helpers.sh

work=$1
chroot=$work/chroot

mkdir -p $work $chroot

# Source any settings shipped by the stage
if [ -f $assets_dir/settings.bash ]
then
  source $assets_dir/settings.bash
fi

# Source any settings persisted by previous stages
if [ -f $work/settings.bash ]
then
  source $work/settings.bash
fi
