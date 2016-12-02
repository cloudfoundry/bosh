set -e # errexit
set -u # nounset
set -x

dir=$(dirname $0)
assets_dir=$dir/assets
base_dir=$(readlink -nf $dir/../..)
lib_dir=$(readlink -nf $base_dir/lib)
skeleton_dir=$(readlink -nf $base_dir/skeleton)
settings_file=$assets_dir/settings.bash
