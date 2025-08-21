module Bosh::Director
  module Jobs::DynamicDisks
    class AttachDynamicDisk < Jobs::BaseJob
      @queue = :normal

      def self.job_type
        :provide_dynamic_disk
      end

      def initialize(agent_id, reply, disk_name)
        super()
        @agent_id = agent_id
        @reply = reply
        @disk_name = disk_name
      end

      def perform
      #   validate_message(@payload)

      #   cloud_properties = find_disk_cloud_properties(@payload['disk_pool_name'])

      #   cloud = Bosh::Director::CloudFactory.create.get(nil)
      #   unless cloud.has_disk(@payload['disk_name'])
      #     raise "Could not find disk #{@payload['disk_name']}"
      #   end

      #   # TODO See if we should use the MetadataUpdater abstraction? It seems like overkill.
      #   if @payload['metadata'] != nil && cloud.respond_to?(:set_disk_metadata)
      #     # TODO implement this
      #     # metadata_updater_cloud = cloud_factory.get(@disk.cpi)
      #     # MetadataUpdater.build.update_dynamic_disk_metadata(metadata_updater_cloud, @disk, @tags)
      #     cloud.set_disk_metadata(disk_name, @payload['metadata'])
      #   end

      #   # TODO record which vm the disk is attached to in the DB
      #   vm_cid = Models::Vm.find(agent_id: @agent_id).cid
      #   disk_hint = cloud.attach_disk(vm_cid, disk_name)

      #   response = {
      #     'error' => nil,
      #     'disk_name' => disk_name,
      #     'disk_hint' => disk_hint,
      #   }
      #   nats_client.send_message(@reply, response)

      #   "attached disk '#{disk_name}' to '#{vm_cid}' in deployment '#{@payload['deployment']}'"
      # rescue => e
      #   nats_client.send_message(@reply, { 'error' => e.message })
      #   raise e
      end

      private

      def nats_client
        Config.nats_rpc
      end

      def find_disk_cloud_properties(disk_pool_name)
        configs = Models::Config.latest_set('cloud')
        raise 'No cloud configs provided' if configs.empty?

        consolidated_configs = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(configs)
        cloud_config_disk_type = DeploymentPlan::CloudManifestParser.new(logger).parse(consolidated_configs.raw_manifest).disk_type(disk_pool_name)
        raise "Could not find disk pool by name `#{disk_pool_name}`" if cloud_config_disk_type.nil?

        cloud_config_disk_type.cloud_properties
      end

      def validate_message(payload)
        if payload['deployment'].nil? || payload['deployment'].empty?
          raise 'Invalid request: `deployment` must be provided'
        elsif payload['disk_name'].nil? || payload['disk_name'].empty?
          raise 'Invalid request: `disk_name` must be provided'
        elsif @reply.nil? || @reply.empty?
          raise 'Invalid request: `disk_pool_name` must be provided'
        end
      end
    end
  end
end