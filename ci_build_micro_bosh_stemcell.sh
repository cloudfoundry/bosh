#!/bin/bash

set -e

sudo rm -rf /mnt/micro-stemcell
if [ -f $WORKSPACE/*.tgz]
then
  rm $WORKSPACE/*.tgz
fi

WORK_PATH=/mnt/micro-stemcell/work BUILD_PATH=/mnt/micro-stemcell/build ./spec/ci_build.sh stemcell:micro[aws]

stemcell=`ls /mnt/micro-stemcell/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell $WORKSPACE/$stemcell_base$BUILD_ID.tgz