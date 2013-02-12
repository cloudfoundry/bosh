#!/bin/bash --login

set -e

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

WORK_PATH=/mnt/$directory/work BUILD_PATH=/mnt/$directory/build $WORKSPACE/spec/ci_build.sh stemcell:$task[aws]

stemcell=`ls /mnt/$directory/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell $WORKSPACE/$stemcell_base$BUILD_ID.tgz