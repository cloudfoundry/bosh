module Bosh::Director
  module DeploymentPlan
    class CloudManifestParser
      include ValidationHelper

      def initialize(deployment, logger)
        @deployment = deployment
        @logger = logger
      end

      def parse(cloud_manifest)
        @cloud_manifest = cloud_manifest

        parse_networks
        parse_compilation
        parse_resource_pools
        parse_disk_pools

        @deployment
      end

      private

      def parse_networks
        networks = safe_property(@cloud_manifest, 'networks', :class => Array)
        networks.each do |network_spec|
          type = safe_property(network_spec, 'type', :class => String,
            :default => 'manual')

          case type
            when 'manual'
              network = ManualNetwork.new(@deployment, network_spec)
            when 'dynamic'
              network = DynamicNetwork.new(@deployment, network_spec)
            when 'vip'
              network = VipNetwork.new(@deployment, network_spec)
            else
              raise DeploymentInvalidNetworkType,
                "Invalid network type `#{type}'"
          end

          @deployment.add_network(network)
        end

        if @deployment.networks.empty?
          raise DeploymentNoNetworks, 'No networks specified'
        end
      end

      def parse_compilation
        compilation_spec = safe_property(@cloud_manifest, 'compilation', :class => Hash)
        @deployment.compilation = CompilationConfig.new(@deployment, compilation_spec)
      end

      def parse_resource_pools
        resource_pools = safe_property(@cloud_manifest, 'resource_pools', :class => Array)
        resource_pools.each do |rp_spec|
          @deployment.add_resource_pool(ResourcePool.new(@deployment, rp_spec, @logger))
        end

        if @deployment.resource_pools.empty?
          raise DeploymentNoResourcePools, 'No resource_pools specified'
        end
      end

      def parse_disk_pools
        disk_pools = safe_property(@cloud_manifest, 'disk_pools', :class => Array, :optional => true)
        return if disk_pools.nil?
        disk_pools.each do |dp_spec|
          @deployment.add_disk_pool(DiskPool.parse(dp_spec))
        end
      end
    end
  end
end
