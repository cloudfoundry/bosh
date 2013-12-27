require 'bosh/dev/vsphere'
require 'logger'
require 'common/retryable'
require 'cloud/vsphere'
require 'sequel'
require 'sequel/adapters/sqlite'
require 'cloud'

module Bosh::Dev::VSphere
  class MicroBoshDeploymentCleaner
    def initialize(manifest)
      @manifest = manifest
      @logger = Logger.new($stderr)
    end

    def clean
      configure_cpi

      cloud = VSphereCloud::Cloud.new(@manifest.to_h['cloud']['properties'])

      old_vms = cloud.get_vms
      return if old_vms.empty?

      old_vms.each do |vm|
        begin
          @logger.info("Powering off #{vm.name}")
          cloud.client.power_off_vm(vm)
          cloud.wait_until_off(vm, 15)

          @logger.info("#{vm.name} powered off, terminating")
          vm.destroy
        rescue
          @logger.info("Destruction of #{vm.inspect} failed, continuing")
        end
      end
    end

    private

    def configure_cpi
      Bosh::Clouds::Config.configure(OpenStruct.new(
        logger: @logger,
        uuid: nil,
        task_checkpoint: nil,
        db: Sequel.sqlite,
      ))
    end
  end
end
