module Bosh::Director
  module Jobs::DynamicDisks
    class ProvideDynamicDisk < Jobs::BaseJob
      include Jobs::Helpers::DynamicDiskHelpers

      @queue = :normal

      def self.job_type
        :provide_dynamic_disk
      end

      def initialize(agent_id, reply, disk_name, disk_pool_name, disk_size, metadata)
        super()
        @agent_id = agent_id
        @reply = reply

        @disk_name = disk_name
        @disk_pool_name = disk_pool_name
        @disk_size = disk_size
        @metadata = metadata
      end

      def perform
        vm = Models::Vm.find(agent_id: @agent_id)
        raise "vm for agent `#{@agent_id}` not found" if vm.nil?

        cloud_properties = find_disk_cloud_properties(vm.instance, @disk_pool_name)
        cloud = Bosh::Director::CloudFactory.create.get(vm.cpi)

        disk_model = Models::DynamicDisk.find(name: @disk_name)
        if disk_model.nil?
          disk_cid = cloud.create_disk(@disk_size, cloud_properties, vm.cid)
          disk_model = Models::DynamicDisk.create(
            name: @disk_name,
            disk_cid: disk_cid,
            deployment_id: vm.instance.deployment.id,
            size: @disk_size,
            disk_pool_name: @disk_pool_name,
            cpi: vm.cpi,
            metadata: @metadata,
          )
        end

        disk_hint = cloud.attach_disk(vm.cid, disk_model.disk_cid)
        disk_model.update(vm_id: vm.id, availability_zone: vm.instance.availability_zone)

        unless @metadata.nil?
          MetadataUpdater.build.update_dynamic_disk_metadata(cloud, disk_model, @metadata)
        end

        response = {
          'error' => nil,
          'disk_name' => @disk_name,
          'disk_hint' => disk_hint,
        }
        nats_rpc.send_message(@reply, response)

        "attached disk `#{@disk_name}` to `#{vm.cid}` in deployment `#{vm.instance.deployment.name}`"
      rescue => e
        nats_rpc.send_message(@reply, { 'error' => e.message })
        raise e
      end
    end
  end
end