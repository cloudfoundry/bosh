module Bosh::Director
  module Jobs::DynamicDisks
    class DetachDynamicDisk < Jobs::BaseJob
      @queue = :normal

      def self.job_type
        :provide_dynamic_disk
      end

      def initialize(agent_id, reply, payload)
        super()
        @agent_id = agent_id
        @reply = reply
        @payload = payload
      end

      def perform
      #   validate_message(@payload)

      #   cloud = Bosh::Director::CloudFactory.create.get(nil)
      #   unless cloud.has_disk(@payload['disk_name'])
      #     raise "Could not find disk #{@payload['disk_name']}"
      #   end

      #   # TODO find disk cid; this may need us to start saving disk state in the db
      #   vm_cid = Models::Vm.find(agent_id: @agent_id).cid
      #   cloud.detach_disk(vm_cid, @disk.disk_cid)

      #   response = {
      #     'error' => nil,
      #   }
      #   nats_rpc.send_message(@reply, response)

      #   "detached disk '#{disk_name}' from '#{vm_cid}' in deployment '#{@payload['deployment']}'"
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