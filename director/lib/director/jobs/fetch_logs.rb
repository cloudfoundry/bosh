module Bosh::Director
  module Jobs
    class FetchLogs < BaseJob
      DEFAULT_BUNDLE_LIFETIME = 86400 * 10 # 10 days
      FETCHLOGS_TAG = "fetch_logs"
      @queue = :normal

      attr_writer :bundle_lifetime

      def initialize(instance_id, options = {})
        @logger = Config.logger
        @blobstore = Config.blobstore
        @event_log = Config.event_log

        @instance_id = instance_id
        @log_type = options["type"] || "job"
        @filters  = options["filters"]
      end

      def perform
        instance = Models::Instance[@instance_id]
        raise "instance #{@instance_id} not found" if instance.nil?

        deployment_name = instance.deployment.name
        deployment_lock = Lock.new("lock:deployment:#{deployment_name}")

        deployment_lock.lock do
          # Cleanup old bundles
          TransitDataManager.cleanup(FETCHLOGS_TAG, bundle_lifetime)

          @event_log.begin_stage("Fetching logs for #{instance.job}/#{instance.index}", 1)

          vm = instance.vm
          raise "instance '#{instance.job}/#{instance.index}' doesn't reference an existing VM" if vm.nil?
          raise "VM '#{vm.cid}' doesn't have an agent id" if vm.agent_id.nil?

          agent = AgentClient.new(vm.agent_id)
          blobstore_id = nil

          track_and_log("Finding and packing log files") do
            # TODO: extract construct below as an AgentClient method
            @logger.info("Fetching logs from agent: log_type='#{@log_type}', filters='#{@filters}'")
            task = agent.fetch_logs(@log_type, @filters)
            while task["state"] == "running"
              sleep(1.0)
              task = agent.get_task(task["agent_task_id"])
            end

            blobstore_id = task["blobstore_id"]
          end

          if blobstore_id.nil?
            raise "agent didn't return a blobstore object id for packaged logs"
          end
          TransitDataManager.add(FETCHLOGS_TAG, blobstore_id)

          # The returned value of this method is used as task result
          # and gets extracted by CLI as a tarball blobstore id
          blobstore_id
        end
      end

      def bundle_lifetime
        @bundle_lifetime || DEFAULT_BUNDLE_LIFETIME
      end

    end
  end
end
