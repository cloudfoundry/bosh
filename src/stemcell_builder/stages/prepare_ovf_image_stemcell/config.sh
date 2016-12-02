#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

persist_value stemcell_image_name

stemcell_disk_format=ovf
persist_value stemcell_disk_format

stemcell_container_format=bare
persist_value stemcell_container_format
