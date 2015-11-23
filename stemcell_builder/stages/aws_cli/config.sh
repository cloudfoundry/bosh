#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir
rm -rf s3cli
mkdir s3cli
current_version=0.0.11
curl -L -o s3cli/s3cli https://s3.amazonaws.com/s3cli-artifacts/s3cli-${current_version}-linux-amd64
echo "d8cfbf440e9c8054a81463c39540b21cdea34dec s3cli/s3cli" | sha1sum -c -
