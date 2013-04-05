#!/bin/bash --login

set -e
source .rvmrc

rm -f *.tgz stemcell-ami.txt

if [ $1 == 'micro' ]
then
  task='micro'
else
  task='basic'
fi

if [ $# == 2 ]; then
  infrastructure=$2
else
  infrastructure='aws'
fi

directory="/mnt/stemcells/$infrastructure-$task"
sudo umount $directory/work/work/mnt/tmp/grub/root.img 2>/dev/null || true
sudo umount $directory/work/work/mnt 2>/dev/null || true

mnt_type=$(df -T "$directory" | awk '/dev/{ print $2 }')
mnt_type=${mnt_type:-unknown}
if [ "$mnt_type" != "btrfs" ]; then
    sudo rm -rf $directory
fi

WORK_PATH=$directory/work \
    BUILD_PATH=$directory/build \
    STEMCELL_VERSION=$BUILD_ID \
    $WORKSPACE/spec/ci_build.sh stemcell:$task[$infrastructure]

files=$(ls $directory/work/work/*.tgz 2> /dev/null || wc -l)
if [ "$files" != "0" ]; then
    stemcell=`ls $directory/work/work/*.tgz`
    stemcell_base=`basename $stemcell .tgz`

    cp $stemcell $WORKSPACE/$stemcell_base.tgz

    if [ $infrastructure == 'aws' ]; then
        bundle exec $(dirname $0)/publish_ami.rb $WORKSPACE/$stemcell_base.tgz
    fi
fi
