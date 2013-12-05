require 'bosh/dev/vsphere'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Cloudstack
  class BatDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env, net_type, director_uuid, stemcell_archive)
      @env = env
      @net_type = net_type
      @director_uuid = director_uuid
      @stemcell_archive = stemcell_archive
      @filename = 'bat.yml'
    end

    def to_h
      manifest_hash = {
        'cpi' => 'cloudstack',
        'properties' => {
          'static_ip' => env['BOSH_CLOUDSTACK_VIP_BAT_IP'],
          'uuid' => director_uuid.value,
          'pool_size' => 1,
          'stemcell' => {
            'name' => stemcell_archive.name,
            'version' => stemcell_archive.version
          },
          'instances' => 1,
          'key_name' => 'jenkins',
          'mbus' => "nats://nats:0b450ada9f830085e2cdeff6@#{env['BOSH_CLOUDSTACK_VIP_BAT_IP']}:4222",
          'network' => {
            'type' => net_type,
            'cloud_properties' => {
              'network_name' => env['BOSH_CLOUDSTACK_NETWORK_NAME'],
              'security_groups' => []
            }
          }
        }
      }

      manifest_hash
    end

    private

    attr_reader :env, :net_type, :stemcell_archive, :director_uuid
  end
end
