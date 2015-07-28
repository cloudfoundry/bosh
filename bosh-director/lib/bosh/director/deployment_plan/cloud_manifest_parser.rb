require 'common/deep_copy'

module Bosh::Director
  module DeploymentPlan
    class CloudManifestParser
      include ValidationHelper

      def initialize(logger)
        @logger = logger
      end

      def parse(cloud_manifest, ip_provider_factory, global_network_resolver)
        @cloud_planner = CloudPlanner.new

        parse_availability_zones(cloud_manifest)
        parse_networks(cloud_manifest, ip_provider_factory, global_network_resolver)
        parse_compilation(cloud_manifest)
        parse_resource_pools(cloud_manifest)
        parse_disk_pools(cloud_manifest)

        @cloud_planner
      end

      private

      def parse_availability_zones(cloud_manifest)
        availability_zones = safe_property(cloud_manifest, 'availability_zones', :class => Array, :optional => true)
        if availability_zones
          availability_zones.each do |availability_zone|
            @cloud_planner.add_availability_zone(AvailabilityZone.new(availability_zone))
          end
        end
      end

      def parse_networks(cloud_manifest, ip_provider_factory, global_network_resolver)
        networks = safe_property(cloud_manifest, 'networks', :class => Array)

        networks.each do |network_spec|
          type = safe_property(network_spec, 'type', :class => String,
            :default => 'manual')

          case type
            when 'manual'
              network = ManualNetwork.new(network_spec, global_network_resolver, ip_provider_factory, @logger)
            when 'dynamic'
              network = DynamicNetwork.new(network_spec, @logger)
            when 'vip'
              network = VipNetwork.new(network_spec, @logger)
            else
              raise DeploymentInvalidNetworkType,
                "Invalid network type `#{type}'"
          end

          @cloud_planner.add_network(network)
        end

        if @cloud_planner.networks.empty?
          raise DeploymentNoNetworks, 'No networks specified'
        end
      end

      def parse_compilation(cloud_manifest)
        compilation_spec = safe_property(cloud_manifest, 'compilation', :class => Hash)
        config = CompilationConfig.new(compilation_spec)
        unless @cloud_planner.network(config.network_name)
            raise CompilationConfigUnknownNetwork,
              "Compilation config references an unknown " +
                "network `#{config.network_name}'"
        end
        @cloud_planner.compilation = config
      end

      def parse_resource_pools(cloud_manifest)
        resource_pools = safe_property(cloud_manifest, 'resource_pools', :class => Array)
        resource_pools.each do |rp_spec|
          @cloud_planner.add_resource_pool(ResourcePool.new(rp_spec, @logger))
        end

        if @cloud_planner.resource_pools.empty?
          raise DeploymentNoResourcePools, 'No resource_pools specified'
        end
      end

      def parse_disk_pools(cloud_manifest)
        disk_pools = safe_property(cloud_manifest, 'disk_pools', :class => Array, :optional => true)
        return if disk_pools.nil?
        disk_pools.each do |dp_spec|
          @cloud_planner.add_disk_pool(DiskPool.parse(dp_spec))
        end
      end
    end
  end
end
