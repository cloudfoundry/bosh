require 'logger'
require 'common/retryable'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud'
require 'ruby_vcloud_sdk'

module Bosh::Dev::VCloud
  class MicroBoshDeploymentCleaner
    def initialize(env, manifest)
      @env = env
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      vdc = find_target_client
      begin
        vapp = vdc.find_vapp_by_name @env['BOSH_VCLOUD_VAPP_NAME']
        vapp.power_off
        vapp.delete
        @logger.info("Vapp #{@env['BOSH_VCLOUD_VAPP_NAME']} was deleted during clean up. ")
      rescue VCloudSdk::ObjectNotFoundError => e
        @logger.info("No vapp was deleted during clean up. Details: #{e}")
      end
    end

    private

    def find_target_client
      vcds = @manifest.to_h['cloud']['properties']['vcds']
      raise ArgumentError, 'Invalid number of arguments' unless vcds && vcds.size == 1
      vcd = vcds[0]
      entities = vcd['entities']

      client = VCloudSdk::Client.new vcd['url'],
                                     "#{vcd['user']}@#{entities['organization']}",
                                     vcd['password'],
                                     {},
                                     @logger

      client.find_vdc_by_name entities['virtual_datacenter']
    end
  end
end
