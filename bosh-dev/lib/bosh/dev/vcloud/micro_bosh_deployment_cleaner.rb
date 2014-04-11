require 'logger'
require 'common/retryable'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud'
require 'ruby_vcloud_sdk'
require 'bosh/dev/vcloud'

module Bosh::Dev::VCloud
  class MicroBoshDeploymentCleaner
    def initialize(env, manifest)
      @env = env
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      initialize_client_and_vdc
      delete_vapp
      clear_catalogs
    end

    private

    def initialize_client_and_vdc
      vcds = @manifest.to_h['cloud']['properties']['vcds']
      raise ArgumentError, 'Must have exactly one vCD' unless vcds && vcds.size == 1

      vcd = vcds[0]
      @client = VCloudSdk::Client.new(vcd['url'],
                                     "#{vcd['user']}@#{vcd['entities']['organization']}",
                                     vcd['password'],
                                     {},
                                     @logger)

      @vdc = @client.find_vdc_by_name(vcd['entities']['virtual_datacenter'])
    end

    def delete_vapp
      vapp = @vdc.find_vapp_by_name(@env['BOSH_VCLOUD_VAPP_NAME'])
      vapp.power_off
      delete_independent_disks(vapp)
      vapp.delete
      @logger.info("Vapp '#{@env['BOSH_VCLOUD_VAPP_NAME']}' was deleted during clean up.")
    rescue VCloudSdk::ObjectNotFoundError => e
      @logger.info("No vapp was deleted during clean up. Details: #{e.inspect}")
    end

    def clear_catalogs
      delete_all_catalog_items(@env['BOSH_VCLOUD_VAPP_CATALOG'])
      delete_all_catalog_items(@env['BOSH_VCLOUD_MEDIA_CATALOG'])
    end

    def delete_all_catalog_items(catalog_name)
      return unless @client.catalog_exists?(catalog_name)

      catalog = @client.find_catalog_by_name(catalog_name)
      catalog.delete_all_items
      @logger.info("Deleted all items from '#{catalog_name}' catalog during clean up.")
    end

    def delete_independent_disks(vapp)
      vapp.vms.each do |vm|
        vm.independent_disks.each do |disk|
          vm.detach_disk(disk)
          disk.delete
        end
      end
    end
  end
end
