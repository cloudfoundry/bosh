module Bosh::Director
  module Jobs
    class FetchLogs < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :fetch_logs
      end

      def initialize(instance_ids, options = {})
        @instance_ids = instance_ids
        @log_type = options["type"] || "job"
        @filters = options["filters"]
        @instance_manager = Api::InstanceManager.new

        @blobstore = options.fetch(:blobstore) { App.instance.blobstores.blobstore }
        @log_bundles_cleaner = LogBundlesCleaner.new(@blobstore, 60 * 60 * 24 * 10, logger) # 10 days
        @logs_fetcher = LogsFetcher.new(@instance_manager, @log_bundles_cleaner, logger)
      end

      def perform
        if @instance_ids.size == 1
          instance = @instance_manager.find_instance(@instance_ids[0])
          blobstore_id, _ = @logs_fetcher.fetch(instance, @log_type, @filters, true)
          blobstore_id
        else
          begin
            download_dir = Dir.mktmpdir
            path = File.join(download_dir, 'logs')
            FileUtils.mkpath(path)

            ThreadPool.new(:max_threads => Config.max_threads).wrap do |pool|
              @instance_ids.each do |instance_id|
                pool.process do
                  generate_and_download(instance_id, path)
                end
              end
            end
            stage = Config.event_log.begin_stage("Fetching group of logs", 1)
            stage.advance_and_track('Packing log files together') do
              archiver = Core::TarGzipper.new
              output_path = File.join(download_dir, "logs_#{Time.now.to_f}.tgz")
              archiver.compress(path, %w(.), output_path)
              blobstore_id = File.open(output_path) { |f| @blobstore.create(f) }
              @log_bundles_cleaner.register_blobstore_id(blobstore_id)
              return blobstore_id
            end
          ensure
            FileUtils.rm_rf(download_dir) if download_dir
          end
        end
      end

      private
      def generate_and_download(instance_id, path)
        instance = @instance_manager.find_instance(instance_id)
        blob_id, _ = @logs_fetcher.fetch(instance, @log_type, @filters, false)
        time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
        File.open(File.join(path, "#{instance.job}.#{instance.uuid}.#{time}.tgz"), 'w') do |f|
          @blobstore.get(blob_id, f)
        end
      ensure
        @blobstore.delete(blob_id) if blob_id
      end
    end
  end
end
