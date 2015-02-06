#!/usr/bin/env bash

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

agent_settings_file=$chroot/var/vcap/bosh/agent.json

if [ "${stemcell_operating_system}" == "centos" ]; then

  # CreatePartitionIfNoEphemeralDisk option is not supported on CentOS
  cat > $agent_settings_file <<JSON
{
  "Infrastructure": {
    "Settings": {
      "DevicePathResolutionType": "virtio",
      "NetworkingType": "dhcp",

      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254"
        },
        {
          "Type": "ConfigDrive",
          "Paths": [
            "/dev/disk/by-label/CONFIG-2",
            "/dev/disk/by-label/config-2"
          ],
          "MetaDataPath": "ec2/latest/meta-data.json",
          "UserDataPath": "ec2/latest/user-data.json"
        }
      ],

      "UseServerName": true,
      "UseRegistry": true
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
  "Infrastructure": {
    "Settings": {
      "DevicePathResolutionType": "virtio",
      "NetworkingType": "dhcp",

      "Sources": [
        {
          "Type": "HTTP",
          "URI": "http://169.254.169.254"
        },
        {
          "Type": "ConfigDrive",
          "Paths": [
            "/dev/disk/by-label/CONFIG-2",
            "/dev/disk/by-label/config-2"
          ],
          "MetaDataPath": "ec2/latest/meta-data.json",
          "UserDataPath": "ec2/latest/user-data.json"
        }
      ],

      "UseServerName": true,
      "UseRegistry": true
    }
  }
}
JSON

fi
