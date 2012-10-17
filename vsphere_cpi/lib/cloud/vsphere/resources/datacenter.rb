# Copyright (c) 2009-2012 VMware, Inc.

module VSphereCloud
  class Resources

    # Datacenter resource.
    class Datacenter
      include VimSdk

      # @!attribute mob
      #   @return [Vim::Datacenter] datacenter vSphere MOB.
      attr_accessor :mob

      # @!attribute clusters
      #   @return [Hash<String, Cluster>] hash of cluster names to clusters.
      attr_accessor :clusters

      # @!attribute vm_folder
      #   @return [Folder] inventory folder for VMs.
      attr_accessor :vm_folder

      # @!attribute template_folder
      #   @return [Folder] inventory folder for stemcells/templates.
      attr_accessor :template_folder

      # @!attribute config
      #   @return [DatacenterConfig] datacenter config.
      attr_accessor :config

      # Creates a new Datacenter resource from the operator provided datacenter
      # configuration.
      #
      # This traverses the provided datacenter/resource pools/datastores and
      # builds the underlying resources and utilization.
      #
      # @param [DatacenterConfig] config datacenter configuration.
      def initialize(config)
        client = Config.client
        @config = config
        @mob = client.find_by_inventory_path(name)
        raise "Datacenter: #{name} not found" if @mob.nil?

        @vm_folder = Folder.new(self, config.folders.vm,
                                config.folders.shared)
        @template_folder = Folder.new(self, config.folders.template,
                                      config.folders.shared)

        cluster_mobs = client.get_managed_objects(
            Vim::ClusterComputeResource, :root => @mob, :include_name => true)
        cluster_mobs.delete_if { |name, _| !config.clusters.has_key?(name) }
        cluster_mobs = Hash[*cluster_mobs.flatten]

        clusters_properties = client.get_properties(
            cluster_mobs.values, Vim::ClusterComputeResource,
            Cluster::PROPERTIES, :ensure_all => true)

        @clusters = {}
        config.clusters.each do |name, cluster_config|
          cluster_mob = cluster_mobs[name]
          raise "Can't find cluster: #{name}" if cluster_mob.nil?
          cluster_properties = clusters_properties[cluster_mob]
          if cluster_properties.nil?
            raise "Can't find properties for cluster: #{name}"
          end
          cluster = Cluster.new(self, cluster_config, cluster_properties)
          @clusters[cluster.name] = cluster
        end
      end

      # @return [String] datacenter name.
      def name
        @config.name
      end

      # @return [String] vCenter path/namespace for VMDKs.
      def disk_path
        @config.datastores.disk_path
      end

      # @return [String] debug datacenter information.
      def inspect
        "<Datacenter: #@mob / #{@config.name}>"
      end
    end
  end
end
