#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_config.bash

# Download CLI source or release from github into assets directory
cd $assets_dir

wget https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.3.3/google-compute-daemon-1.3.3-1.noarch.rpm
echo "d116bf65e5fbafe591da82e65d717c4a677492c2 google-compute-daemon-1.3.3-1.noarch.rpm" | sha1sum -c -

wget https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.3.3/google-compute-daemon_1.3.3-1_all.deb
echo "cb03e2fc7f0eea1b24bb3ec46ed015175fe054af google-compute-daemon_1.3.3-1_all.deb" | sha1sum -c -

wget https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.3.3/google-startup-scripts-1.3.3-1.noarch.rpm
echo "bfcfc9861f9882fd2bd942819de95db4f56348cc google-startup-scripts-1.3.3-1.noarch.rpm" | sha1sum -c -

wget https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.3.3/google-startup-scripts_1.3.3-1_all.deb
echo "7a67a6581a921636a564777a12ff04fe3b0966fa google-startup-scripts_1.3.3-1_all.deb" | sha1sum -c -
