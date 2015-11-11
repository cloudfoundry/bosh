module Bosh::Director::Jobs
  module Helpers
    class StemcellDeleter
      include Bosh::Director::LockHelper

      def initialize(cloud, compiled_package_deleter, logger, event_log)
        @cloud = cloud
        @compiled_package_deleter = compiled_package_deleter
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
            @cloud.delete_stemcell(stemcell.cid)
          rescue => e
            raise unless options['force']
            @logger.warn(e.backtrace.join("\n"))
            @logger.info("Force deleting is set, ignoring exception: #{e.message}")
          end

          @logger.info('Looking for any compiled packages on this stemcell')
          compiled_packages = Bosh::Director::Models::CompiledPackage.filter(:stemcell_id => stemcell.id)

          stage = @event_log.begin_stage('Deleting compiled packages',
            compiled_packages.count, [stemcell.name, stemcell.version])
          @logger.info('Deleting compiled packages ' +
              "(#{compiled_packages.count}) for `#{stemcell.name}/#{stemcell.version}'")

          compiled_packages.each do |compiled_package|
            message = "#{compiled_package.name}/#{compiled_package.version}"
            stage.advance_and_track(message) do
              @logger.info(message)
              @compiled_package_deleter.delete(compiled_package, options)
            end
          end

          stemcell.destroy
        end
      end

      private

      def track_and_log(stage, task, log = true)
        stage.advance_and_track(task) do |ticker|
          @logger.info(task) if log
          yield ticker if block_given?
        end
      end
    end
  end
end
