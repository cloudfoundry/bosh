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
RET=$?

rm -f $BASE/config/micro.yml $BASE/config/micro.tgz
echo '============= compilation finished ============='

if [ $RET -ne 0 ]; then
	exit 1
fi
