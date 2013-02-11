#!/bin/bash

set -e

sudo rm -rf /mnt/stemcell
if [ -f $WORKSPACE/*.tgz]
then
  rm $WORKSPACE/*.tgz
fi

WORK_PATH=/mnt/stemcell/work BUILD_PATH=/mnt/stemcell/build ./spec/ci_build.sh stemcell:basic[aws]

stemcell=`ls /mnt/stemcell/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell $WORKSPACE/$stemcell_base$BUILD_ID.tgz