#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e
set -x

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ -z "${bosh_agent_src_dir:-}" ]
then
  # Use relative path to the BOSH agent
  bosh_agent_src_dir=$(readlink -nf $base_dir/../bosh_agent)
fi

if [ -z "${bosh_release_src_dir:-}" ]
then
  # Use relative path to the BOSH release
  bosh_release_src_dir=$(readlink -nf $base_dir/../release/src/bosh)
fi

if [ -z "${mcf_enabled:-}" ]
then
  mcf_enabled=no
fi

# Find `ruby` in PATH if needed
if [ -z "${ruby_bin:-}" ]
then
  if which ruby >/dev/null
  then
    ruby_bin=$(which ruby)
  fi
fi

# Abort when $ruby_bin is empty
if [ -z "${ruby_bin:-}" ]
then
  echo "ruby_bin is empty"
  exit 1
fi

# Abort when $ruby_bin is not executable
if [ ! -x $ruby_bin ]
then
  echo "$ruby_bin is not executable"
  exit 1
fi

ruby="$ruby_bin -I$bosh_agent_src_dir/lib"
bosh_agent_src_version=$($ruby -r"bosh_agent/version" -e"puts Bosh::Agent::VERSION")

persist_dir bosh_agent_src_dir

cp -aL $bosh_release_src_dir/bosh_agent $assets_dir/gems

persist_value bosh_agent_src_version
persist_value mcf_enabled
