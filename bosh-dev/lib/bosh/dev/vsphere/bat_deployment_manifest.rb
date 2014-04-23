require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::VSphere
  class BatDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, director_uuid, stemcell_archive)
      @env = env
      @director_uuid = director_uuid
      @stemcell_archive = stemcell_archive
      @filename = 'bat.yml'
    end

    def to_h
      {
        'cpi' => 'vsphere',
        'properties' => {
          'uuid' => director_uuid.value,
          'static_ip' => env['BOSH_VSPHERE_BAT_IP'],
          'second_static_ip' => env['BOSH_VSPHERE_SECOND_BAT_IP'],
          'pool_size' => 1,
          'stemcell' => {
            'name' => stemcell_archive.name,
            'version' => stemcell_archive.version,
          },
          'instances' => 1,
          'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_VSPHERE_BAT_IP']}:4222",
          'network' => {
            'type' => 'manual',
            'cidr' => env['BOSH_VSPHERE_NETWORK_CIDR'],
            'reserved' => env['BOSH_VSPHERE_NETWORK_RESERVED'].split(/[|,]/).map(&:strip),
            'static' => [env['BOSH_VSPHERE_NETWORK_STATIC']],
            'gateway' => env['BOSH_VSPHERE_NETWORK_GATEWAY'],
            'vlan' => env['BOSH_VSPHERE_NET_ID'],
          },
        },
      }
    end

    private

    attr_reader :env, :stemcell_archive, :director_uuid
  end
end
