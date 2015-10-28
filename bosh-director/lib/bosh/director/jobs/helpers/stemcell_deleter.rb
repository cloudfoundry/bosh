module Bosh::Director::Jobs
  module Helpers
    class StemcellDeleter
      include Bosh::Director::LockHelper

      def initialize(cloud, blobstore, logger, event_log)
        @cloud = cloud
        @blobstore = blobstore
        @logger = logger
        @event_log = event_log
      end

      def delete(stemcell, options = {})
        with_stemcell_lock(stemcell.name, stemcell.version) do
          @logger.info('Checking for any deployments still using the stemcell')
          deployments = stemcell.deployments
          unless deployments.empty?
            names = deployments.map { |d| d.name }.join(', ')
            raise Bosh::Director::StemcellInUse,
              "Stemcell `#{stemcell.name}/#{stemcell.version}' is still in use by: #{names}"
          end

          begin
            @event_log.begin_stage('Deleting stemcell from cloud', 1)

            @event_log.track('Delete stemcell') do
              @cloud.delete_stemcell(stemcell.cid)
            end
          rescue => e
            raise unless options['force']
            @logger.warn(e.backtrace.join("\n"))
            @logger.info("Force deleting is set, ignoring exception: #{e.message}")
          end

          @logger.info('Looking for any compiled packages on this stemcell')
          compiled_packages =
            Bosh::Director::Models::CompiledPackage.filter(:stemcell_id => stemcell.id)

          @event_log.begin_stage('Deleting compiled packages',
            compiled_packages.count, [stemcell.name, stemcell.version])
          @logger.info('Deleting compiled packages ' +
              "(#{compiled_packages.count}) for `#{stemcell.name}/#{stemcell.version}'")

          compiled_packages.each do |compiled_package|
            next unless compiled_package

            package = compiled_package.package
            track_and_log("#{package.name}/#{package.version}") do
              @logger.info('Deleting compiled package: ' +
                  "#{package.name}/#{package.version}")
              @blobstore.delete(compiled_package.blobstore_id)
              compiled_package.destroy
            end
          end

          @event_log.begin_stage('Deleting stemcell metadata', 1)
          @event_log.track('Deleting stemcell metadata') do
            stemcell.destroy
          end
        end
      end

      private

      def track_and_log(task, log = true)
        @event_log.track(task) do |ticker|
          @logger.info(task) if log
          yield ticker if block_given?
        end
      end
    end
  end
end
