#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_bosh.bash
source $base_dir/lib/prelude_apply.bash

mkdir -p $chroot/$bosh_dir/src
mkdir -p $chroot/usr/lib64

libyaml_basename=yaml-0.1.7
libyaml_archive=$libyaml_basename.tar.gz

cp -r $dir/assets/$libyaml_archive $chroot/$bosh_dir/src

run_in_bosh_chroot $chroot "
cd src
tar zxvf $libyaml_archive
cd $libyaml_basename
./configure --prefix=/usr
make -j4 && make install
"

for file in $(cd $chroot/usr/lib; ls libyaml*); do
  if [ ! -e $chroot/usr/lib64/$file ]; then
    cp -a $chroot/usr/lib/$file $chroot/usr/lib64/
  fi
done
