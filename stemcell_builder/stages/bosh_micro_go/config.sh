#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e


base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ ${bosh_micro_enabled:-no} == "yes" ]
then
  persist_dir bosh_micro_package_compiler_path
  persist_file bosh_micro_manifest_yml_path
  persist_file bosh_micro_release_tgz_path
  persist_value stemcell_infrastructure
  persist_value stemcell_operating_system
fi

if [ -z "${agent_gem_src_url:-}" ]; then
  mkdir -p $assets_dir/gems
  cp -rvH $bosh_release_src_dir/bosh-release/* $assets_dir/gems
else
  persist_value agent_gem_src_url
fi
