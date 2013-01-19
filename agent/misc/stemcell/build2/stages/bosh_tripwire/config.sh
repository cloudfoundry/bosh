#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

if [ ! -z "${TW_LOCAL_PASSPHRASE:-}" ]
then
  persist TW_LOCAL_PASSPHRASE
fi

if [ ! -z "${TW_SITE_PASSPHRASE:-}" ]
then
  persist TW_SITE_PASSPHRASE
fi
