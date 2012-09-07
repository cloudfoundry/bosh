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
  persist_value system_parameters_infrastructure
fi
