module Bosh::Director
  module Jobs::DynamicDisks
    class CreateDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :dynamic_disks

      def self.job_type
        :create_dynamic_disk
      end

      def initialize(deployment_name, az, disk_name, disk_pool_name, disk_size, metadata)
        @deployment_name = deployment_name
        @az = az
        @disk_name = disk_name
        @disk_pool_name = disk_pool_name
        @disk_size = disk_size
        @metadata = metadata
      end

      def perform
        disk_model = Models::DynamicDisk.find(name: @disk_name)
        raise "disk `#{@disk_name}` already exists" unless disk_model.nil?

        deployment = Models::Deployment.find(name: @deployment_name)
        raise "deployment `#{@deployment_name}` not found" if deployment.nil?

        # Find an active VM in the requested AZ to use as the hint for create_disk.
        # The IaaS uses the VM's location to determine which AZ/datastore to place the disk in.
        vm = find_active_vm_in_az(deployment, @az)
        raise "no active VM found in deployment `#{@deployment_name}` in AZ `#{@az}`" if vm.nil?

        cloud = Bosh::Director::CloudFactory.create.get(vm.cpi)

        cloud_properties = find_disk_cloud_properties(deployment, @disk_pool_name).clone
        cloud_properties['name'] = @disk_name

        disk_cid = cloud.create_disk(@disk_size, cloud_properties, vm.cid)
        begin
          disk_model = Models::DynamicDisk.create(
            name: @disk_name,
            disk_cid: disk_cid,
            deployment_id: deployment.id,
            size: @disk_size,
            disk_pool_name: @disk_pool_name,
            cpi: vm.cpi,
            availability_zone: @az,
          )
        rescue
          cloud.delete_disk(disk_cid)
          raise
        end

        if !@metadata.nil? && disk_model.metadata != @metadata
          MetadataUpdater.build.update_dynamic_disk_metadata(cloud, disk_model, @metadata)
          disk_model.update(metadata: @metadata)
        end

        disk_info = { disk_cid: disk_model.disk_cid }

        task_result.write(JSON.generate(disk_info))
        task_result.write("\n")

        "created disk `#{@disk_name}` in deployment `#{deployment.name}` in AZ `#{@az}`"
      end

      private

      def find_active_vm_in_az(deployment, az)
        deployment.instances
          .select { |i| i.availability_zone == az }
          .flat_map { |i| i.vms.select(&:active) }
          .first
      end
    end
  end
end
