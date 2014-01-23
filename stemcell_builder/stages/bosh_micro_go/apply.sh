#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e
set -x

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

mkdir -p $chroot/$bosh_dir/src/micro_bosh/bosh-release
if [ -z "${agent_gem_src_url:-}" ]; then
  cp -rvH $assets_dir/gems $chroot/$bosh_dir/src/micro_bosh/bosh-release/gems
fi

cp -rH $bosh_micro_manifest_yml_path $chroot/$bosh_dir/src/micro_bosh/release.yml
cp -rH $bosh_micro_release_tgz_path $chroot/$bosh_dir/src/micro_bosh/release.tgz
cp $dir/assets/configure_micro_bosh.sh $chroot/$bosh_dir/src/micro_bosh/configure_micro_bosh.sh

run_in_bosh_chroot $chroot "$bosh_dir/src/micro_bosh/configure_micro_bosh.sh ${stemcell_infrastructure} ${agent_gem_src_url:-}"

# Copy the generated apply spec to stemcell directory
mkdir -p $work/stemcell
# go_agent expects a json file on disk, microbosh deployer expects a yaml file (fortunately json is yaml)
cp $chroot/$bosh_app_dir/micro/apply_spec.json $work/stemcell/apply_spec.yml
