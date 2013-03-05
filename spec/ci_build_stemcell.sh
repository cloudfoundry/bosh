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

directory="$infrastructure-$task"

sudo rm -rf /mnt/$directory

WORK_PATH=/mnt/$directory/work \
    BUILD_PATH=/mnt/$directory/build \
    STEMCELL_VERSION=$BUILD_ID \
    $WORKSPACE/spec/ci_build.sh stemcell:$task[$infrastructure]

stemcell=`ls /mnt/$directory/work/work/*.tgz`
stemcell_base=`basename $stemcell .tgz`

cp $stemcell $WORKSPACE/$stemcell_base.tgz

if [ $infrastructure == 'aws' ]; then
    bundle exec $(dirname $0)/publish_ami.rb $WORKSPACE/$stemcell_base.tgz
fi
