#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e
set -x

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src/micro_bosh/package_compiler
cp -rvH $assets_dir/gems $chroot/$bosh_dir/src/micro_bosh/package_compiler/gems
cp -rH $bosh_micro_manifest_yml_path $chroot/$bosh_dir/src/micro_bosh/release.yml
cp -rH $bosh_micro_release_tgz_path $chroot/$bosh_dir/src/micro_bosh/release.tgz
if [ ${mcf_enabled:-no} == "yes" ]; then
  cp $dir/assets/configure_micro_bosh_for_mcf.sh $chroot/$bosh_dir/src/micro_bosh/configure_micro_bosh.sh
else
  cp $dir/assets/configure_micro_bosh.sh $chroot/$bosh_dir/src/micro_bosh/configure_micro_bosh.sh
fi

apt_get install libpq-dev genisoimage
run_in_bosh_chroot $chroot "$bosh_dir/src/micro_bosh/configure_micro_bosh.sh ${system_parameters_infrastructure}"

# Copy the generated apply spec to stemcell directory
mkdir -p $work/stemcell
cp $chroot/$bosh_app_dir/micro/apply_spec.yml $work/stemcell
