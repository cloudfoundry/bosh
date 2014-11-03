module Bosh::Deployer::InfrastructureDefaults
  AWS = {
    'name' => nil,
    'logging' => {
      'level' => 'INFO'
    },
    'dir' => nil,
    'network' => {
      'type' => 'dynamic',
      'cloud_properties' => {}
    },
    'env' => {
      'bosh' => {
        'password' => nil
      }
    },
    'resources' => {
      'persistent_disk' => 4096,
      'cloud_properties' => {
        'instance_type' => 'm1.small',
        'availability_zone' => nil
      }
    },
    'cloud' => {
      'plugin' => 'aws',
      'properties' => {
        'aws' => {
          'access_key_id' => nil,
          'secret_access_key' => nil,
          'ec2_endpoint' => nil,
          'max_retries' => 2,
          'http_read_timeout' => 60,
          'http_wire_trace' => false,
          'default_key_name' => nil,
          'default_security_groups' => [],
          'ssh_user' => 'vcap'
        },
        'registry' => {
          'endpoint' => 'http://admin:admin@localhost:25888',
          'user' => 'admin',
          'password' => 'admin'
        },
        'stemcell' => {
          'kernel_id' => nil,
          'disk' => 4096
        },
        'agent' => {
          'ntp' => [],
          'blobstore' => {
            'provider' => 'local',
            'options' => {
              'blobstore_path' => '/var/vcap/micro_bosh/data/cache'
            }
          },
          'mbus' => nil
        }
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
