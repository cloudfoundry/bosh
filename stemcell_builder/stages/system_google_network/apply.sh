#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Add Google Compute Engine Metadata endpoint to hosts file
cat >> $chroot/etc/hosts <<EOS
# Google Compute Engine Metadata endpoint
169.254.169.254 metadata.google.internal metadata
EOS
