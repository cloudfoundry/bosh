#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download package source from github into assets directory
cd $assets_dir

# Download google-image-packages
wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-compute-engine-init-ubuntu-trusty_2.1.0-0.1474671297_amd64.deb
echo "8081f1a3a92c7a64b762f8382dc42c952633cb08  google-compute-engine-init-ubuntu-trusty_2.1.0-0.1474671297_amd64.deb" | sha1sum -c -

wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-compute-engine-wheezy_2.1.3-0.1474395669_all.deb
echo "820d7d06afd7a60d884fea1570a6e5ba108b967b  google-compute-engine-wheezy_2.1.3-0.1474395669_all.deb" | sha1sum -c -
