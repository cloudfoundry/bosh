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
      config = OpenStruct.new(logger: @logger, uuid: nil, task_checkpoint: nil, db: Sequel.sqlite)
      Bosh::Clouds::Config.configure(config)

      cloud = get_cloud(@manifest)
      old_vms = cloud.get_vms
      unless old_vms.empty?
        @logger.info('Terminating instances')

        old_vms.each do |vm|
          begin
            vm.destroy
          rescue
            @logger.info("Destruction of #{vm.inspect} failed, continuing")
          end
        end
      end
    end

    private

    def get_cloud(manifest)
      vsphere_properties = manifest.to_h['cloud']['properties']

      VSphereCloud::Cloud.new(vsphere_properties)
    end
  end
end
