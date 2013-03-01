#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source ${base_dir}/lib/prelude_apply.bash

# Add build version to micro code.
sed \
    --in-place=.prev \
    "s/VERSION = \".*\"$/VERSION = \"${version}\"/" \
    ${micro_src}/micro/lib/micro/version.rb
