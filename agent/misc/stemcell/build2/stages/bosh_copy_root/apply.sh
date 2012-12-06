#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Workaround for Bosh CLI validation. Bosh CLI thinks all the stemcell without
# an image is an invalid stemcell
touch $work/stemcell/image

# Copy root
time rsync -aHA $chroot/* $work/stemcell/root
