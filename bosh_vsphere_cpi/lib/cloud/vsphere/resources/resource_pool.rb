module VSphereCloud
  class Resources
    class ResourcePool
      include VimSdk

      # @!attribute mob
      #   @return [Vim::ResourcePool] resource pool vSphere MOB.
      attr_accessor :mob

      # Creates a new ResourcePool resource.
      #
      # @param [Cluster] cluster parent cluster.
      # @param [Vim::ResourcePool] root_resource_pool cluster's root resource
      #   pool.
      def initialize(cluster, root_resource_pool)
        if cluster.config.resource_pool.nil?
          @mob = root_resource_pool
        else
          client = Config.client
          logger = Config.logger
          @mob = client.get_managed_object(
              Vim::ResourcePool,
              :root => root_resource_pool,
              :name => cluster.config.resource_pool)
          logger.debug("Found requested resource pool: #@mob")
        end
      end

      # @return [String] debug resource pool information.
      def inspect
        "<Resource Pool: #@mob>"
      end
    end
  end
end