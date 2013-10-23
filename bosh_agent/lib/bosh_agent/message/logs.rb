# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module Message
    class FetchLogs < Base

      def self.long_running?
        true
      end

      def self.process(args)
        new(args).process
      end

      attr_accessor :matcher, :aggregator

      def initialize(args)
        @log_type = args[0]
        @filters = Set.new(args[1])
        @state = Bosh::Agent::Config.state.to_hash
        @matcher = default_matcher
        @aggregator = Bosh::Agent::FileAggregator.new
      end

      def process
        handler_error("matcher for #{@log_type} logs not found") unless @matcher
        handler_error("aggregator for #{@log_type} logs not found") unless @aggregator

        if @filters && @filters.size > 0
          @matcher.globs = filter_globs
        end

        aggregator.matcher = @matcher

        tarball_path = aggregator.generate_tarball
        tarball_size = File.size(tarball_path)

        logger.info("Generated log tarball: #{tarball_path} (size: #{tarball_size})")
        blobstore_id = upload_tarball(tarball_path)

        { "blobstore_id" => blobstore_id }

      rescue Bosh::Agent::FileAggregator::DirectoryNotFound => e
        handler_error("unable to find #{@log_type} logs directory")
      rescue Bosh::Agent::FileAggregator::Error => e
        handler_error("error aggregating logs: #{e}")
      ensure
        aggregator.cleanup
      end

      private

      def default_matcher
        case @log_type.to_s
        when "job"
          Bosh::Agent::JobLogMatcher.new(base_dir)
        when "agent"
          Bosh::Agent::AgentLogMatcher.new(base_dir)
        else
          nil
        end
      end

      def filter_globs
        custom_job_logs = {}

        if @state["job"] && @state["job"]["logs"]
          logs_spec = @state["job"]["logs"]

          if logs_spec.is_a?(Hash)
            custom_job_logs = logs_spec
          else
            logger.warn("Invalid format for job logs spec: Hash expected, #{logs_spec.class} given")
            logger.warn("All custom filtering except '--all' thus disabled")
          end
        end

        predefined = { "all" => "**/*" }

        predefined.merge(custom_job_logs).inject([]) do |result, (filter_name, glob)|
          result << glob if @filters.include?(filter_name)
          result
        end
      end

      # @return blobstore id of the uploaded tarball
      def upload_tarball(path)
        bsc_options  = Bosh::Agent::Config.blobstore_options
        bsc_provider = Bosh::Agent::Config.blobstore_provider
        blobstore = Bosh::Blobstore::Client.safe_create(bsc_provider, bsc_options)

        logger.info("Uploading tarball to blobstore")
        blobstore_id = nil

        File.open(path) do |f|
          blobstore_id = blobstore.create(f)
        end

        blobstore_id
      rescue Bosh::Blobstore::BlobstoreError => e
        handler_error("unable to upload logs to blobstore: #{e}")
      end

    end
  end
end
