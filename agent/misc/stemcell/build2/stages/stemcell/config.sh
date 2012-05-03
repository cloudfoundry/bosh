#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

assert_not_empty stemcell_name
assert_not_empty stemcell_version
assert_not_empty stemcell_format
assert_not_empty bosh_protocol_version
