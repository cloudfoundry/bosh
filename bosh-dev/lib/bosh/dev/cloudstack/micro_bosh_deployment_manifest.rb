require 'bosh/dev/cloudstack'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Cloudstack
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
        'name' => "microbosh-cloudstack-#{net_type}",
        'logging' => {
          'level' => 'DEBUG'
        },
        'network' => {
          'type' => net_type,
          'vip' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP'],
          'cloud_properties' => {
            'network_name' => env['BOSH_CLOUDSTACK_NETWORK_NAME']
          }
        },
        'resources' => {
          'persistent_disk' => 4096,
          'cloud_properties' => {
            'instance_type' => 'm1.small'
          }
        },
        'cloud' => {
          'plugin' => 'cloudstack',
          'properties' => {
            'cloudstack' => {
              'endpoint' => env['BOSH_CLOUDSTACK_ENDPOINT'],
              'api_key' => env['BOSH_CLOUDSTACK_API_KEY'],
              'secret_access_key' => env['BOSH_CLOUDSTACK_SECRET_ACCESS_KEY'],
              'default_key_name' => 'jenkins',
              'default_security_groups' => [],
              'default_key_name' => env['BOSH_CLOUDSTACK_DEFAULT_KEY_NAME'],
              'private_key' => env['BOSH_CLOUDSTACK_PRIVATE_KEY'],
              'default_zone' => env['BOSH_CLOUDSTACK_DEFAULT_ZONE'],
            }
          }
        },
        'apply_spec' => {
          'agent' => {
            'blobstore' => {
              'address' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP']
            },
            'nats' => {
              'address' => env['BOSH_CLOUDSTACK_VIP_DIRECTOR_IP']
            }
          },
          'properties' => {}
        }
      }

      result['network']['ip'] = env['BOSH_CLOUDSTACK_MANUAL_IP'] if net_type == 'manual'

      result
    end

    private

    attr_reader :env, :net_type
  end
end
