require 'bosh/dev/vcloud'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::VCloud
  class MicroBoshDeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename

    def initialize(env)
      @env = env
      @filename = 'micro_bosh.yml'
    end

    def to_h
      {
        'name' => 'microbosh-vcloud-jenkins',
        'network' => {
          'name' => 'micro-network',
          'vip' => @env['BOSH_VCLOUD_MICROBOSH_VIP'],
          'ip' => @env['BOSH_VCLOUD_MICROBOSH_IP'],
          'netmask' => @env['BOSH_VCLOUD_NETMASK'],
          'gateway' => @env['BOSH_VCLOUD_GATEWAY'],
          'dns' => [@env['BOSH_VCLOUD_DNS']],
          'cloud_properties' => { 'name' => @env['BOSH_VCLOUD_NET_ID'] }
        },
        'resources' => {
            'persistent_disk' => 4096,
            'cloud_properties' => {'ram' => 2048, 'disk' => 8192, 'cpu' => 1}
        },
        'cloud' => {
          'plugin' => 'vcloud',
          'properties' => {
            'agent' => {'ntp' => [@env['BOSH_VCLOUD_NTP_SERVER']]},
            'vcds' => [
              {
                'url' => @env['BOSH_VCLOUD_URL'],
                'user' => @env['BOSH_VCLOUD_USER'],
                'password' => @env['BOSH_VCLOUD_PASSWORD'],
                'entities' => {
                  'organization' => @env['BOSH_VCLOUD_ORG'],
                  'virtual_datacenter' => @env['BOSH_VCLOUD_VDC'],
                  'vapp_catalog' => @env['BOSH_VCLOUD_VAPP_CATALOG'],
                  'media_catalog' => @env['BOSH_VCLOUD_MEDIA_CATALOG'],
                  'media_storage_profile' => @env['BOSH_VCLOUD_MEDIA_STORAGE_PROFILE'],
                  'vm_metadata_key' => @env['BOSH_VCLOUD_VM_METADATA_KEY'],
                  'description' => 'MicroBosh on vCloudDirector',
                  'control' => {'wait_max' => @env['BOSH_VCLOUD_WAIT_MAX'].to_i || 300}
                }
              }
            ]
          }
        },
        'env' => {'vapp' => @env['BOSH_VCLOUD_VAPP_NAME']},
        'logging' => {'level' => 'debug'},
      }
    end
  end
end
