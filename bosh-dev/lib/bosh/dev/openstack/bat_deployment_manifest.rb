require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev
  module Openstack
    class BatDeploymentManifest
      include WritableManifest

      def initialize(net_type, director_uuid, stemcell_version)
        @env = ENV.to_hash
        @net_type = net_type
        @director_uuid = director_uuid
        @stemcell_version = stemcell_version
      end

      def to_h
        manifest_hash = {
          'cpi' => 'openstack',
          'properties' =>
            {
              'static_ip' => env['BOSH_OPENSTACK_VIP_BAT_IP'],
              'uuid' => director_uuid,
              'pool_size' => 1,
              'stemcell' => { 'name' => 'bosh-stemcell', 'version' => stemcell_version },
              'instances' => 1,
              'key_name' => 'jenkins',
              'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_OPENSTACK_VIP_BAT_IP']}:4222",
            }
        }

        if net_type == 'manual'
          manifest_hash['properties']['network'] = {
            'cidr' => env['BOSH_OPENSTACK_NETWORK_CIDR'],
            'reserved' => [env['BOSH_OPENSTACK_NETWORK_RESERVED']],
            'static' => [env['BOSH_OPENSTACK_NETWORK_STATIC']],
            'gateway' => env['BOSH_OPENSTACK_NETWORK_GATEWAY'],
            'security_groups' => ['default'],
            'net_id' => env['BOSH_OPENSTACK_NET_ID']
          }
        else
          manifest_hash['properties']['security_groups'] = 'default'
        end

        manifest_hash
      end

      private

      attr_reader :env, :net_type, :stemcell_version, :director_uuid
    end
  end
end
