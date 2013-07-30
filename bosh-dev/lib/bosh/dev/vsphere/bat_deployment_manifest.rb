require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev
  module VSphere
    class BatDeploymentManifest
      include WritableManifest

      attr_reader :filename

      def initialize(director_uuid, stemcell_version)
        @env = ENV.to_hash
        @director_uuid = director_uuid
        @stemcell_version = stemcell_version
        @filename = 'bat.yml'
      end

      def to_h
        { 'cpi' => 'vsphere',
          'properties' =>
            { 'uuid' => director_uuid,
              'static_ip' => env['BOSH_VSPHERE_BAT_IP'],
              'pool_size' => 1,
              'stemcell' => { 'name' => 'bosh-stemcell', 'version' => stemcell_version },
              'instances' => 1,
              'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_VSPHERE_BAT_IP']}:4222",
              'network' =>
                { 'cidr' => env['BOSH_VSPHERE_NETWORK_CIDR'],
                  'reserved' => env['BOSH_VSPHERE_NETWORK_RESERVED'].split(/[|,]/).map(&:strip),
                  'static' => [env['BOSH_VSPHERE_NETWORK_STATIC']],
                  'gateway' => env['BOSH_VSPHERE_NETWORK_GATEWAY'],
                  'vlan' => env['BOSH_VSPHERE_NET_ID'] } } }
      end

      private

      attr_reader :env, :stemcell_version, :director_uuid
    end
  end
end
