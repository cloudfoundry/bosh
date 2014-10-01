#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

if [ "`uname -m`" == "ppc64le" ]; then
  # temporary hack because bosh_micro stage is not running
  mkdir -p $work/stemcell
fi


pushd $work
tar zcf stemcell/image root.img
popd
