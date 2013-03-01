#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

assert_available debootstrap

if [ ! -z "${UBUNTU_ISO:-}" ]
then
  persist UBUNTU_ISO
fi

if [ ! -z "${UBUNTU_MIRROR:-}" ]
then
  persist UBUNTU_MIRROR
fi

base_debootstrap_arch=amd64

if [ -z "${base_debootstrap_suite:-}" ]
then
  base_debootstrap_suite=lucid
fi

persist_value base_debootstrap_arch
persist_value base_debootstrap_suite
