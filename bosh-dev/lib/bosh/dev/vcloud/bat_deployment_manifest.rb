require 'bosh/dev/vcloud'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::VCloud
  class BatDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename, :net_type

    def initialize(env, net_type, director_uuid, stemcell_archive)
      @env = env
      @net_type = net_type
      @director_uuid = director_uuid
      @stemcell_archive = stemcell_archive
      @filename = 'bat.yml'

      unless net_type == 'manual'
        raise "Specified #{net_type} networking but environment requires manual"
      end
    end

    def to_h
      {
        'cpi' => 'vcloud',
        'properties' => {
          'uuid' => director_uuid.value,
          'second_static_ip' => env['BOSH_VCLOUD_SECOND_BAT_IP'],
          'pool_size' => 1,
          'stemcell' => {
            'name' => stemcell_archive.name,
            'version' => stemcell_archive.version
          },
          'instances' => 1,
          'networks' => [
            {
              'name' => 'static',
              'static_ip' => env['BOSH_VCLOUD_BAT_IP'],
              'type' => 'manual',
              'cidr' => env['BOSH_VCLOUD_NETWORK_CIDR'],
              'reserved' => env['BOSH_VCLOUD_NETWORK_RESERVED'].split(/[|,]/).map(&:strip),
              'static' => [env['BOSH_VCLOUD_NETWORK_STATIC']],
              'gateway' => env['BOSH_VCLOUD_NETWORK_GATEWAY'],
              'vlan' => env['BOSH_VCLOUD_NET_ID']
            },
          ],
          'vapp_name' => env['BOSH_VCLOUD_VAPP_NAME'],
          'vcds' => [
            {
              'control' => {
                'time_limit_sec' => {
                  'default' => 360
                }
              }
            }
          ]
        }
      }
    end

    private

    attr_reader :env, :stemcell_archive, :director_uuid
  end
end
