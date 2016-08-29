#!/usr/bin/env bash

set -ex

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/bosh-start-logging-and-auditing $chroot/var/vcap/bosh/bin/
