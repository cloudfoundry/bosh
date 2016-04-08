require 'bosh/dev/openstack'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Openstack
  class MicroBoshDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type)
      @env = env
      @net_type = net_type
      @filename = 'micro_bosh.yml'
    end

    def to_h
      result = {
        'name' => director_name,
        'logging' => {
          'level' => 'DEBUG'
        },
        'network' => {
          'type' => net_type,
          'vip' => env['BOSH_OPENSTACK_VIP_DIRECTOR_IP'],
          'cloud_properties' => {}
        },
        'resources' => {
          'persistent_disk' => 4096,
          'cloud_properties' => {
            'instance_type' => env.fetch('BOSH_OPENSTACK_FLAVOR', 'm1.small'),
          }
        },
        'cloud' => {
          'plugin' => 'openstack',
          'properties' => cpi_options,
        },
        'apply_spec' => {
          'agent' => {
            'blobstore' => {
              'address' => env['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
            },
            'nats' => {
              'address' => env['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
            }
          },
          'properties' => {
            'director' => {
              'debug' => {
                'keep_unreachable_vms' => env.fetch('BAT_DEBUG_MODE', false)
              },
              'max_vm_create_tries' => 15
            },
          },
        },
      }

      if env['BOSH_OPENSTACK_MICRO_NET_ID']
        result['network']['cloud_properties']['net_id'] = env['BOSH_OPENSTACK_MICRO_NET_ID']
      end

      result['network']['ip'] = env['BOSH_OPENSTACK_MANUAL_IP'] if net_type == 'manual'

      result
    end

    def director_name
      "microbosh-openstack-#{net_type}"
    end

    def cpi_options
      {
        'openstack' => {
          'auth_url' => env['BOSH_OPENSTACK_AUTH_URL'],
          'username' => env['BOSH_OPENSTACK_USERNAME'],
          'api_key' => env['BOSH_OPENSTACK_API_KEY'],
          'tenant' => env['BOSH_OPENSTACK_TENANT'],
          'region' => env['BOSH_OPENSTACK_REGION'],
          'endpoint_type' => 'publicURL',
          'default_key_name' => default_key_name,
          'default_security_groups' => default_security_groups,
          'private_key' => env['BOSH_OPENSTACK_PRIVATE_KEY'],
          'state_timeout' => state_timeout,
          'wait_resource_poll_interval' => 5,
          'connection_options' => {
            'connect_timeout' => connection_timeout,
          }
        },
        'registry' => {
          'endpoint' => "http://admin:admin@localhost:#{env['BOSH_OPENSTACK_REGISTRY_PORT'] || 25889}",
          'user' => 'admin',
          'password' => 'admin',
        },
      }
    end

    private

    attr_reader :env, :net_type

    def state_timeout
      timeout = env['BOSH_OPENSTACK_STATE_TIMEOUT']
      timeout.to_s.empty? ? 300.0 : timeout.to_f
    end

    def connection_timeout
      timeout = env['BOSH_OPENSTACK_CONNECTION_TIMEOUT']
      timeout.to_s.empty? ? 60.0 : timeout.to_f
    end

    def default_key_name
      key_name = env['BOSH_OPENSTACK_DEFAULT_KEY_NAME']
      key_name.to_s.empty? ? 'jenkins' : key_name
    end

    def default_security_groups
      group = env['BOSH_OPENSTACK_DEFAULT_SECURITY_GROUP']
      group.to_s.empty? ? ['default'] : [group]
    end
  end
end
