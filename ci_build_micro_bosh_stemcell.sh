#!/bin/bash

set -e

sudo rm -rf /mnt/micro-stemcell
rm *.tgz

WORK_PATH=/mnt/micro-stemcell/work BUILD_PATH=/mnt/micro-stemcell/build ./spec/ci_build.sh stemcell:micro[aws]

stemcell=`ls /mnt/micro-stemcell/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell ./$stemcell_base$BUILD_ID.tgz