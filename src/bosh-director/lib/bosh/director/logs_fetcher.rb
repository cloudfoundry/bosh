module Bosh::Director
  class LogsFetcher
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Bosh::Director::Api::InstanceManager] instance_manager
    # @param [Bosh::Director::LogBundlesCleaner] log_bundles_cleaner
    def initialize(instance_manager, log_bundles_cleaner, logger)
      @instance_manager = instance_manager
      @log_bundles_cleaner = log_bundles_cleaner
      @logger = logger
      @blobstore = App.instance.blobstores.blobstore
    end

    # @param [Models::Instance] instance
    # @param [String] log_type
    # @param [Array] filters
    def fetch(instance, log_type, filters, persist_blobstore_id = false)
      @logger.info("Fetching logs from agent with log_type=#{log_type} filters=#{filters}")

      @log_bundles_cleaner.clean

      agent = @instance_manager.agent_client_for(instance)
      blobstore_id = nil
      sha_digest = nil

      stage = Config.event_log.begin_stage("Fetching logs for #{instance.job}/#{instance.uuid} (#{instance.index})", 1)
      stage.advance_and_track('Finding and packing log files') do
        if @blobstore.signing_enabled? && instance.active_vm.stemcell_api_version >= 3
          blobstore_id = SecureRandom.uuid
          signed_url = @blobstore.sign(blobstore_id, 'put')
          fetch_logs_result = agent.fetch_logs_with_signed_url(signed_url: signed_url, log_type: log_type, filters: filters)
        else
          fetch_logs_result = agent.fetch_logs(log_type, filters)
          blobstore_id = fetch_logs_result['blobstore_id']

          if blobstore_id.nil?
            raise AgentTaskNoBlobstoreId,
                  "Agent didn't return a blobstore object id for packaged logs"
          end
        end
        sha_digest = fetch_logs_result['sha1']
      end

      @log_bundles_cleaner.register_blobstore_id(blobstore_id) if persist_blobstore_id

      return blobstore_id, sha_digest
    end
  end
end
