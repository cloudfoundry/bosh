#!/bin/bash --login

set -e

source .rvmrc

rm -f *.tgz stemcell-ami.txt

if [ $1 == 'micro' ]
then
  task='micro'
  directory='micro-stemcell'
else
  task='basic'
  directory='stemcell'
fi

sudo rm -rf /mnt/$directory
if [ -f $WORKSPACE/*.tgz ]
then
  rm $WORKSPACE/*.tgz
fi

WORK_PATH=/mnt/$directory/work \
    BUILD_PATH=/mnt/$directory/build \
    STEMCELL_VERSION=$BUILD_ID \
    $WORKSPACE/spec/ci_build.sh stemcell:$task[aws]

stemcell=`ls /mnt/$directory/work/work/*.tgz`
stemcell_base=`basename $stemcell .tgz`

cp $stemcell $WORKSPACE/$stemcell_base.tgz

bundle exec $(dirname $0)/publish_ami.rb $WORKSPACE/$stemcell_base.tgz
