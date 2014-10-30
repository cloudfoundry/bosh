#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf s3cli
curl -L -o s3cli.tar.gz https://api.github.com/repos/pivotal-golang/s3cli/tarball/2c4a7f0ceef411532bb051e7ca55a490a565cf60
mkdir s3cli
tar -xzf s3cli.tar.gz -C s3cli/ --strip-components 1
