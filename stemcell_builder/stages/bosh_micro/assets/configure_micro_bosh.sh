#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

if [ $# -ne 1 ]
then
  echo "Usage: env `basename $0` [infrastructure]"
  exit 1
fi

infrastructure=$1

bosh_src_dir=/var/vcap/bosh/src/micro_bosh
bosh_app_dir=/var/vcap
blobstore_path=${bosh_app_dir}/micro_bosh/data/cache
agent_host=localhost
agent_port=6969
agent_uri=http://vcap:vcap@${agent_host}:${agent_port}

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

(
  cd ${bosh_src_dir}/package_compiler/gems
  gem install package_compiler --no-rdoc --no-ri -l -w #-i ${bosh_src_dir}/bosh/gems
)

mkdir -p ${bosh_app_dir}/bosh/blob
mkdir -p ${blobstore_path}

echo "Starting micro bosh compilation"

# Start agent
/var/vcap/bosh/bin/bosh_agent -I ${infrastructure} -n ${agent_uri} -s ${blobstore_path} -p local &
agent_pid=$!
echo "Starting BOSH Agent for compiling micro bosh package, agent pid is $agent_pid"

# Wait for agent to start
function wait_agent {
  for i in {1..10}
  do
    nc -z $1 $2 && break
    sleep 1
  done
}
wait_agent ${agent_host} ${agent_port}

# Start compiler
package_compiler \
  --cpi ${infrastructure} \
  compile \
    ${bosh_src_dir}/release.yml \
    ${bosh_src_dir}/release.tgz \
    ${blobstore_path} \
    ${agent_uri}

function kill_agent {
  signal=$1
  kill -$signal $agent_pid > /dev/null 2>&1
}

kill_agent 15
# Wait for agent
for i in {1..5}
do
  kill_agent 0 && break
  sleep 1
done
# Force kill if required
kill_agent 0 || kill_agent 9

# Clean out src
cd /var/tmp
rm -fr ${bosh_app_dir}/bosh/src
