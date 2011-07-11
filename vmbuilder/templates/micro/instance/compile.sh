#!/bin/sh
#

# make sure we use the right ruby
PATH=/var/vcap/bosh/bin:$PATH
export PATH

BASE=/var/vcap/micro
export BASE

echo '============= starting compilation ============='
cd $BASE
bundle install --local

bin/compile $BASE/config/micro.yml $BASE/config/micro.tgz
echo '============= compilation finished ============='
