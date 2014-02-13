module VSphereCloud
  class Resources
    class Datacenter
      include VimSdk

      attr_accessor :config

      def initialize(config)
        @config = config
      end

      def mob
        mob = @config.client.find_by_inventory_path(name)
        raise "Datacenter: #{name} not found" if mob.nil?
        mob
      end

      def vm_folder
        Folder.new(@config.datacenter_vm_folder, @config)
      end

      def template_folder
        Folder.new(@config.datacenter_template_folder, @config)
      end

      def name
        @config.datacenter_name
      end

      def disk_path
        @config.datacenter_disk_path
      end

      def ephemeral_pattern
        @config.datacenter_datastore_pattern
      end

      def persistent_pattern
        @config.datacenter_persistent_datastore_pattern
      end

      def allow_mixed
        @config.datacenter_allow_mixed_datastores
      end

      def inspect
        "<Datacenter: #{mob} / #{name}>"
      end

      def clusters
        client = @config.client
        cluster_mobs = client.get_managed_objects(
          Vim::ClusterComputeResource, root: mob, include_name: true)
        cluster_mobs.delete_if { |name, _| !config.datacenter_clusters.has_key?(name) }
        cluster_mobs = Hash[*cluster_mobs.flatten]

        clusters_properties = client.get_properties(
          cluster_mobs.values, Vim::ClusterComputeResource,
          Cluster::PROPERTIES, :ensure_all => true)

        clusters = {}
        config.datacenter_clusters.each do |cluster_name, cluster_config|
          cluster_mob = cluster_mobs[cluster_name]
          raise "Can't find cluster: #{cluster_name}" if cluster_mob.nil?

          cluster_properties = clusters_properties[cluster_mob]
          raise "Can't find properties for cluster: #{cluster_name}" if cluster_properties.nil?

          cluster = Cluster.new(self, @config, cluster_config, cluster_properties)
          clusters[cluster.name] = cluster
        end
        clusters
      end
    end
  end
end
