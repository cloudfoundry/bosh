require 'bosh/dev/vsphere'
require 'common/retryable'
require 'cloud/vsphere'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud'
require 'logging'

module Bosh::Dev::VSphere
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logging.logger(STDERR)
    end

    def clean
      configure_cpi

      cloud = VSphereCloud::Cloud.new(@manifest.to_h['cloud']['properties'])

      old_vms = cloud.get_vms
      return if old_vms.empty?

      old_vms.each do |vm|
        begin
          @logger.info("Powering off #{vm.cid}")
          vm.power_off
          vm.wait_until_off(15)

          @logger.info("#{vm.cid} powered off, terminating")
          vm.delete
        rescue Exception => e
          @logger.info("Destruction of #{vm.inspect} failed with #{e.class}: #{e.message}. Manual cleanup may be required. Continuing and hoping for the best...")
        end
      end
    end

    private

    def configure_cpi
      Bosh::Clouds::Config.configure(OpenStruct.new(
        logger: @logger,
        uuid: SecureRandom.uuid,
        task_checkpoint: nil,
        db: Sequel.sqlite,
      ))
    end
  end
end
