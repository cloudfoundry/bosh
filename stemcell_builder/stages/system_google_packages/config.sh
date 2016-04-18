#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download package source from github into assets directory
cd $assets_dir

wget -O compute-src.tar.gz https://github.com/GoogleCloudPlatform/compute-image-packages/archive/1.3.3.tar.gz
echo "dd115b7d56c08a3c62180a9b72552a54f7babd4f compute-src.tar.gz" | sha1sum -c -

mkdir compute-src
tar xvf compute-src.tar.gz -C compute-src
cp -R compute-src/compute-image-packages-1.3.3/google-daemon/{etc,usr} .
rm -rf compute-src compute-src.tar.gz
