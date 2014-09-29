#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

agent_settings_file=$chroot/var/vcap/bosh/agent.json

if [ "${stemcell_operating_system}" == "centos" ]; then

  cat > $agent_settings_file <<JSON
{
  "Infrastructure" : {
    "MetadataService": {
      "UseConfigDrive": true
    }
  }
}
JSON

else

  cat > $agent_settings_file <<JSON
{
  "Platform": {
    "Linux": {
      "CreatePartitionIfNoEphemeralDisk": true
    }
  },
  "Infrastructure" : {
    "MetadataService": {
      "UseConfigDrive": true
    }
  }
}
JSON

fi
