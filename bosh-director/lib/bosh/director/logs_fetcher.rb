module Bosh::Director
  class LogsFetcher
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Bosh::Director::Api::InstanceManager] instance_manager
    # @param [Bosh::Director::LogBundlesCleaner] log_bundles_cleaner
    def initialize(event_log, instance_manager, log_bundles_cleaner, logger)
      @event_log = event_log
      @instance_manager = instance_manager
      @log_bundles_cleaner = log_bundles_cleaner
      @logger = logger
    end

    # @param [Models::Instance] instance
    # @param [String] log_type
    # @param [Array] filters
    def fetch(instance, log_type, filters)
      @logger.info("Fetching logs from agent with log_type=#{log_type} filters=#{filters}")

      @log_bundles_cleaner.clean

      agent = @instance_manager.agent_client_for(instance)
      blobstore_id = nil

      stage = @event_log.begin_stage("Fetching logs for #{instance.job}/#{instance.index}", 1)
      stage.advance_and_track('Finding and packing log files') do
        fetch_logs_result = agent.fetch_logs(log_type, filters)
        blobstore_id = fetch_logs_result['blobstore_id']
      end

      if blobstore_id.nil?
        raise AgentTaskNoBlobstoreId,
              "Agent didn't return a blobstore object id for packaged logs"
      end

      @log_bundles_cleaner.register_blobstore_id(blobstore_id)

      blobstore_id
    end
  end
end
