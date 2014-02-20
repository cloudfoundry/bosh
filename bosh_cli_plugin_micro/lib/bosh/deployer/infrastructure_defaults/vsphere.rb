module Bosh::Deployer::InfrastructureDefaults
  VSPHERE = {
    'name' => nil,
    'logging' => {
      'level' => 'INFO'
    },
    'dir' => nil,
    'network' => {
      'ip' => nil,
      'netmask' => nil,
      'gateway' => nil,
      'dns' => [],
      'cloud_properties' => {
        'name' => nil
      }
    },
    'env' => {
      'bosh' => {
        'password' => nil
      }
    },
    'resources' => {
      'persistent_disk' => 4096,
      'cloud_properties' => {
        'ram' => 1024,
        'disk' => 4096,
        'cpu' => 1
      }
    },
    'cloud' => {
      'plugin' => 'vsphere',
      'properties' => {
        'agent' => {
          'ntp' => [],
          'blobstore' => {
            'provider' => 'local',
            'options' => {
              'blobstore_path' => '/var/vcap/micro_bosh/data/cache'
            }
          },
          'mbus' => nil
        },
        'vcenters' => []
      }
    },
    'apply_spec' => {
      'properties' => {},
      'agent' => {
        'blobstore' => {},
        'nats' => {}
      }
    }
  }
end
