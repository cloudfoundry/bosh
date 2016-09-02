module Bosh::Director::Jobs
  module Helpers
    class StemcellDeleter
      include Bosh::Director::LockHelper

      def initialize(cloud, logger)
        @cloud = cloud
        @logger = logger
      end

      def delete(stemcell, options = {})
        with_stemcell_lock(stemcell.name, stemcell.version) do
          @logger.info('Checking for any deployments still using the stemcell')
          deployments = stemcell.deployments
          unless deployments.empty?
            names = deployments.map { |d| d.name }.join(', ')
            raise Bosh::Director::StemcellInUse,
              "Stemcell '#{stemcell.name}/#{stemcell.version}' is still in use by: #{names}"
          end

          begin
            @cloud.delete_stemcell(stemcell.cid)
          rescue => e
            raise unless options['force']
            @logger.warn(e.backtrace.join("\n"))
            @logger.info("Force deleting is set, ignoring exception: #{e.message}")
          end

          stemcell.destroy
        end
      end
    end
  end
end
