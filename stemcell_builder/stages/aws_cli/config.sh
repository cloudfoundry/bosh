#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf s3cli
curl -L -o s3cli.tar.gz https://api.github.com/repos/pivotal-golang/s3cli/tarball/d8ad6e8d05784195f2a83ebb459d6f755cf69d17
mkdir s3cli
tar -xzf s3cli.tar.gz -C s3cli/ --strip-components 1
