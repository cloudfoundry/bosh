#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Use OVFTOOL if needed
if [ -z "${image_ovftool_path:-}" ]
then
  if [ -n "${OVFTOOL:-}" ]
  then
    image_ovftool_path=$OVFTOOL
  fi
fi

# Find `ovftool` in PATH if needed
if [ -z "${image_ovftool_path:-}" ]
then
  if which ovftool >/dev/null
  then
    image_ovftool_path=$(which ovftool)
  fi
fi

# Abort when $image_ovftool_path is empty
if [ -z "${image_ovftool_path:-}" ]
then
  echo "image_ovftool_path is empty"
  exit 1
fi

# Abort when $image_ovftool_path is not executable
if [ ! -x $image_ovftool_path ]
then
  echo "$image_ovftool_path is not executable"
  exit 1
fi

persist_value image_ovftool_path
