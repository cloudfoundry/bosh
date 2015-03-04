module VSphereCloud
  class Resources
    class ResourcePool
      include VimSdk

      # Creates a new ResourcePool resource.
      #
      # @param [Cluster] cluster parent cluster.
      # @param [Vim::ResourcePool] root_resource_pool cluster's root resource
      #   pool.
      def initialize(cloud_config, cluster_config, root_resource_pool)
        @cloud_config = cloud_config
        @cluster_config = cluster_config
        @root_resource_pool = root_resource_pool
      end

      def mob
        return @mob if @mob

        if @cluster_config.resource_pool.nil?
          @mob = @root_resource_pool
        else
          client = @cloud_config.client
          logger = @cloud_config.logger
          @mob = client.cloud_searcher.get_managed_object(
            Vim::ResourcePool,
            :root => @root_resource_pool,
            :name => @cluster_config.resource_pool)
          logger.debug("Found requested resource pool: #{@mob}")
        end
        @mob
      end

      # @return [String] debug resource pool information.
      def inspect
        "<Resource Pool: #{mob}>"
      end
    end
  end
end
