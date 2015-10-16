#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

assert_available qemu-img
persist_value stemcell_image_name

stemcell_disk_format=vhd
persist_value stemcell_disk_format
