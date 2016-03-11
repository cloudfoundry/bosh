#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

bosh_micro_enabled="${bosh_micro_enabled:-no}"
persist_value bosh_micro_enabled
