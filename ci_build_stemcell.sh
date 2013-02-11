#!/bin/bash

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
if [ -f $WORKSPACE/*.tgz]
then
  rm $WORKSPACE/*.tgz
fi

source .rvmrc
gem list | grep bundler > /dev/null || gem install bundler
bundle check || bundle install --without development


WORK_PATH=/mnt/$directory/work BUILD_PATH=/mnt/$directory/build bundle exec rake stemcell:$task[aws]

stemcell=`ls /mnt/$directory/work/work/*.tgz`
stemcell_base=`basename $stemcell tgz`

cp $stemcell $WORKSPACE/$stemcell_base$BUILD_ID.tgz