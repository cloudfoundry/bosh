module VSphereCloud
  class Resources
    class ClusterProvider
      def initialize(datacenter, client, logger)
        @datacenter = datacenter
        @client = client
        @logger = logger
      end

      def find(name, config)
        cluster_mob = cluster_mobs[name]
        raise "Can't find cluster: #{name}" if cluster_mob.nil?

        cluster_properties = @client.cloud_searcher.get_properties(
          cluster_mob, VimSdk::Vim::ClusterComputeResource,
          Cluster::PROPERTIES, :ensure_all => true
        )
        raise "Can't find properties for cluster: #{name}" if cluster_properties.nil?

        Cluster.new(
          @datacenter,
          @datacenter.ephemeral_pattern,
          @datacenter.persistent_pattern,
          @datacenter.mem_overcommit,
          config,
          cluster_properties,
          @logger,
          @client
        )
      end

      private

      def cluster_mobs
        @cluster_mobs ||= begin
          cluster_tuples = @client.cloud_searcher.get_managed_objects(
            VimSdk::Vim::ClusterComputeResource,
            root: @datacenter.mob,
            include_name: true
          )
          Hash[*(cluster_tuples.flatten)]
        end
      end
    end
  end
end
