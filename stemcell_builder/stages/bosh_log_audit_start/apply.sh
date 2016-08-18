#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/start_logging_and_auditing.sh $chroot/var/vcap/bosh/bin/
