require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Openstack
  class BatDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename, :net_type

    def initialize(env, net_type, director_uuid, stemcell_archive)
      @env = env
      @net_type = net_type
      @director_uuid = director_uuid
      @stemcell_archive = stemcell_archive
      @filename = 'bat.yml'
    end

    def to_h
      manifest_hash = {
        'cpi' => 'openstack',
        'properties' => {
          'vip' => env['BOSH_OPENSTACK_VIP_BAT_IP'],
          'networks' => [
            {
              'name' => 'default',
              'static_ip' => env['BOSH_OPENSTACK_STATIC_BAT_IP_0'],
              'type' => net_type,
              'cloud_properties' => {
                'security_groups' => ['default']
              },
            },
            {
              'name' => 'second',
              'static_ip' => env['BOSH_OPENSTACK_STATIC_BAT_IP_1'],
              'type' => net_type,
              'cloud_properties' => {
                'security_groups' => ['default']
              }
            },
          ],
          'second_static_ip' => env['BOSH_OPENSTACK_SECOND_STATIC_BAT_IP'],
          'uuid' => director_uuid.value,
          'pool_size' => 1,
          'stemcell' => {
            'name' => stemcell_archive.name,
            'version' => stemcell_archive.version
          },
          'instance_type' => env['BOSH_OPENSTACK_FLAVOR'],
          'flavor_with_no_ephemeral_disk' => env['BOSH_OPENSTACK_FLAVOR_WITH_NO_EPHEMERAL_DISK'],
          'instances' => 1,
          'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_OPENSTACK_VIP_BAT_IP']}:4222",
        }
      }

      key_name = env['BOSH_OPENSTACK_KEY_NAME']
      unless key_name.to_s.empty?
        manifest_hash['properties']['key_name'] = key_name
      end

      if env['BOSH_OPENSTACK_NET_ID_0']
        manifest_hash['properties']['networks'][0]['cloud_properties']['net_id'] = env['BOSH_OPENSTACK_NET_ID_0']
      end
      if env['BOSH_OPENSTACK_NET_ID_1']
        manifest_hash['properties']['networks'][1]['cloud_properties']['net_id'] = env['BOSH_OPENSTACK_NET_ID_1']
      end

      manifest_hash['properties']['networks'].each_with_index do |network, i|
        if net_type == 'manual'
          network.merge!(
            'cidr' => env["BOSH_OPENSTACK_NETWORK_CIDR_#{i}"],
            'reserved' => [env["BOSH_OPENSTACK_NETWORK_RESERVED_#{i}"]],
            'static' => [env["BOSH_OPENSTACK_NETWORK_STATIC_#{i}"]],
            'gateway' => env["BOSH_OPENSTACK_NETWORK_GATEWAY_#{i}"]
          )
        end
      end

      manifest_hash
    end

    private

    attr_reader :env, :stemcell_archive, :director_uuid
  end
end
