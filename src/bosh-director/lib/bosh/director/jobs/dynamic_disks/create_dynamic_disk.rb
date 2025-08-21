module Bosh::Director
  module Jobs::DynamicDisks
    class CreateDynamicDisk < Jobs::BaseJob
      @queue = :normal

      def self.job_type
        :create_dynamic_disk
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
      #   validate_message(@payload)

      #   cloud_properties = find_disk_cloud_properties(@payload['disk_pool_name'])

      #   cloud = Bosh::Director::CloudFactory.create.get(nil)
      #   if cloud.has_disk(@payload['disk_name'])
      #     raise "disk '#{}'"
      #     # TODO: save in database
      #   end

      #   # TODO this still needed?
      #   if @payload['metadata'] != nil && cloud.respond_to?(:set_disk_metadata)
      #     cloud.set_disk_metadata(disk_name, @payload['metadata'])
      #   end

      #   disk_name = cloud.create_disk(@payload['disk_size'], cloud_properties, nil)
      #   # TODO save disk name to db

      #   response = {
      #     'error' => nil,
      #     'disk_name' => disk_name,
      #     'disk_hint' => disk_hint,
      #   }
      #   nats_rpc.send_message(@reply, response)

      #   "created disk '#{disk_name}' in deployment '#{@payload['deployment']}'"
      # rescue => e
      #   nats_rpc.send_message(@reply, { 'error' => e.message })
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
        elsif payload['disk_size'].nil? || payload['disk_size'] == 0
          raise 'Invalid request: `disk_size` must be provided'
        elsif payload['disk_pool_name'].nil? || payload['disk_pool_name'].empty?
          raise 'Invalid request: `disk_pool_name` must be provided'
        elsif @reply.nil? || @reply.empty?
          raise 'Invalid request: `disk_pool_name` must be provided'
        end
      end
    end
  end
end