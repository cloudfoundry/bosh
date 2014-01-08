#!/bin/bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

if [ $# -lt 1 ]
then
  echo "Usage: env `basename $0` [infrastructure] [agent_gem_src_url]"
  exit 1
fi

infrastructure=$1
agent_gem_src_url=$2

bosh_src_dir=/var/vcap/bosh/src/micro_bosh
bosh_app_dir=/var/vcap
blobstore_path=${bosh_app_dir}/micro_bosh/data/cache
agent_host=localhost
agent_port=6969
agent_uri=https://vcap:vcap@${agent_host}:${agent_port}

export PATH=${bosh_app_dir}/bosh/bin:$PATH
export HOME=/root

if [ -z "${agent_gem_src_url:-}" ]; then
(
  cd ${bosh_src_dir}/bosh-release/gems
  gem install bosh-release --no-rdoc --no-ri -l -w
)
else
  gem install bosh-release -r --no-rdoc --no-ri -w --pre --source ${agent_gem_src_url}
fi

mkdir -p ${bosh_app_dir}/bosh/blob

echo "Starting micro bosh compilation"


cat > ${bosh_app_dir}/bosh/settings.json << EOF
{
  "agent_id": "not_configured",
  "mbus": "$agent_uri",
  "blobstore": {
    "provider": "local",
    "options": {
      "blobstore_path": "$blobstore_path"
    }
  }
}
EOF
# Start agent
/var/vcap/bosh/bin/bosh_agent -I dummy &
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

bosh-release \
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
rm ${bosh_app_dir}/bosh/settings.json
