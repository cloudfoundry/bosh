require 'bosh/dev/openstack'
require 'bosh/dev/writable_manifest'

module Bosh::Dev
  module Openstack
    class MicroBoshDeploymentManifest
      include WritableManifest

      attr_reader :filename

      def initialize(net_type)
        @env = ENV.to_hash
        @net_type = net_type
        @filename = 'micro_bosh.yml'
      end

      def to_h
        result = {
          'name' => "microbosh-openstack-#{net_type}",
          'logging' => {
            'level' => 'DEBUG'
          },
          'network' => {
            'type' => net_type,
            'vip' => env['BOSH_OPENSTACK_VIP_DIRECTOR_IP']
          },
          'resources' => {
            'persistent_disk' => 4096,
            'cloud_properties' => {
              'instance_type' => 'm1.small'
            }
          },
          'cloud' => {
            'plugin' => 'openstack',
            'properties' => {
              'openstack' => {
                'auth_url' => env['BOSH_OPENSTACK_AUTH_URL'],
                'username' => env['BOSH_OPENSTACK_USERNAME'],
                'api_key' => env['BOSH_OPENSTACK_API_KEY'],
                'tenant' => env['BOSH_OPENSTACK_TENANT'],
                'region' => env['BOSH_OPENSTACK_REGION'],
                'endpoint_type' => 'publicURL',
                'default_key_name' => 'jenkins',
                'default_security_groups' => ['default'],
                'private_key' => env['BOSH_OPENSTACK_PRIVATE_KEY']
              }
            }
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
            'properties' => {}
          }
        }

        if net_type == 'manual'
          result['network'].merge!(
            'ip' => env['BOSH_OPENSTACK_MANUAL_IP'],
            'cloud_properties' => {
              'net_id' => env['BOSH_OPENSTACK_NET_ID']
            }
          )
        end

        result
      end

      private

      attr_reader :env, :net_type
    end
  end
end
