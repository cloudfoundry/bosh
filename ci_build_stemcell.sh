#!/bin/bash

set -e

sudo rm -rf /mnt/stemcell
rm *.tgz

WORK_PATH=/mnt/stemcell/work BUILD_PATH=/mnt/stemcell/build ./spec/ci_build.sh stemcell:basic[aws]

stemcell=`ls /mnt/stemcell/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell ./$stemcell_base$BUILD_ID.tgz