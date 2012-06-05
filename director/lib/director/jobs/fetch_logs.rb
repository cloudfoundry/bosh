# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Jobs
    class FetchLogs < BaseJob
      DEFAULT_BUNDLE_LIFETIME = 86400 * 10 # 10 days

      @queue = :normal

      attr_accessor :bundle_lifetime

      def initialize(instance_id, options = {})
        super

        @blobstore = Config.blobstore
        @instance_id = instance_id
        @log_type = options["type"] || "job"
        @filters = options["filters"]
        @instance_manager = Api::InstanceManager.new
        @bundle_lifetime = DEFAULT_BUNDLE_LIFETIME
      end

      def perform
        instance = @instance_manager.find_instance(@instance_id)
        desc = "#{instance.job}/#{instance.index}"

        deployment = instance.deployment

        if deployment.nil?
          raise InstanceDeploymentMissing,
                "`#{desc}' doesn't belong to any deployment"
        end

        deployment_name = deployment.name
        deployment_lock = Lock.new("lock:deployment:#{deployment_name}")

        deployment_lock.lock do
          cleanup_old_bundles

          event_log.begin_stage("Fetching logs for #{desc}", 1)

          agent = @instance_manager.agent_client_for(instance)
          blobstore_id = nil

          track_and_log("Finding and packing log files") do
            logger.info("Fetching logs from agent: " +
                         "log_type='#{@log_type}', filters='#{@filters}'")

            task = agent.fetch_logs(@log_type, @filters)
            # TODO: should be using result?
            blobstore_id = task["blobstore_id"]
          end

          if blobstore_id.nil?
            raise AgentTaskNoBlobstoreId,
                  "Agent didn't return a blobstore object id for packaged logs"
          end

          Models::LogBundle.create(:blobstore_id => blobstore_id,
                                   :timestamp => Time.now)

          # The returned value of this method is used as task result
          # and gets extracted by CLI as a tarball blobstore id
          blobstore_id
        end
      end

      def cleanup_old_bundles
        old_bundles = Models::LogBundle.filter("timestamp <= ?",
                                               Time.now - bundle_lifetime)
        count = old_bundles.count

        if count == 0
          logger.info("No old bundles to delete")
          return
        end

        logger.info("Deleting #{count} old log bundle#{count > 1 ? "s" : ""}")

        old_bundles.each do |bundle|
          begin
            logger.info("Deleting log bundle #{bundle.id}: " +
                        "#{bundle.blobstore_id}")
            @blobstore.delete(bundle.blobstore_id)
            bundle.delete
          rescue Bosh::Blobstore::BlobstoreError => e
            logger.warn("Could not delete #{bundle.blobstore_id}: #{e}")
            # Assuming object has been deleted from blobstore by someone else,
            # cleaning up DB record accordingly
            if e.kind_of?(Bosh::Blobstore::NotFound)
              bundle.delete
            end
          end
        end
      end

    end
  end
end
