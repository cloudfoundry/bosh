#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download package source from github into assets directory
mkdir -p $assets_dir/google-ubuntu
cd $assets_dir/google-ubuntu

# Download google-image-packages ubuntu
wget https://storage.googleapis.com/bosh-cpi-artifacts/google-compute-engine-init-trusty_2.1.0-0.1474913068_amd64.deb
echo "229a1cd551b865cab199516e7572412fa4fde903  google-compute-engine-init-trusty_2.1.0-0.1474913068_amd64.deb" | sha1sum -c -

wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-compute-engine-trusty_2.2.3-0.1474912841_all.deb
echo "0da71ccd637145f34ef4e97bcdc741d5b8177081  google-compute-engine-trusty_2.2.3-0.1474912841_all.deb" | sha1sum -c -

wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-config-trusty_2.0.0-0.1474912881_amd64.deb
echo "d8cc6556a73e5766a032230b900f6a24e30e66df  google-config-trusty_2.0.0-0.1474912881_amd64.deb" | sha1sum -c -


# Download package source from github into assets directory
mkdir -p $assets_dir/google-centos
cd $assets_dir/google-centos

# Download google-image-packages ubuntu
wget https://storage.googleapis.com/bosh-cpi-artifacts/google-compute-engine-init-2.1.0-0.el7.x86_64.rpm
echo "67e47c9322293170518c05510edb9dfef1e2dfe7  google-compute-engine-init-2.1.0-0.el7.x86_64.rpm" | sha1sum -c -

wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-compute-engine-2.2.3-0.el7.noarch.rpm
echo "7763b63e058a420b8acc04edc6e35a9e2ef59b29 google-compute-engine-2.2.3-0.el7.noarch.rpm" | sha1sum -c -

wget https://storage.googleapis.com/bosh-stemcell-artifacts/google-config-2.0.0-0.el7.x86_64.rpm
echo "403c1f7cc294b2331646a73d78cce68075621b78 google-config-2.0.0-0.el7.x86_64.rpm" | sha1sum -c -
