require 'common/deep_copy'

module Bosh::Director
  module DeploymentPlan
    class CloudManifestParser
      include ValidationHelper

      def initialize(logger)
        @logger = logger
      end

      def parse(cloud_manifest, ip_provider_factory, global_network_resolver)
        azs = parse_availability_zones(cloud_manifest)
        networks = parse_networks(cloud_manifest, ip_provider_factory, global_network_resolver)
        compilation_config = parse_compilation(cloud_manifest, networks)
        resource_pools = parse_resource_pools(cloud_manifest)
        disk_pools = parse_disk_pools(cloud_manifest)

        cloud_planner = CloudPlanner.new
        azs.each { |az| cloud_planner.add_availability_zone(az) }
        networks.each { |network| cloud_planner.add_network(network) }
        cloud_planner.compilation = compilation_config
        resource_pools.each { |rp| cloud_planner.add_resource_pool(rp) }
        disk_pools.each { |dp| cloud_planner.add_disk_pool(dp) }
        cloud_planner
      end

      private

      def parse_availability_zones(cloud_manifest)
        availability_zones = safe_property(cloud_manifest, 'availability_zones', :class => Array, :optional => true, :default => [])
        parsed_availability_zones = availability_zones.map do |availability_zone|
          AvailabilityZone.new(availability_zone)
        end

        duplicates = detect_duplicates(parsed_availability_zones) { |az| az.name }
        unless duplicates.empty?
          raise DeploymentDuplicateAvailabilityZoneName, "Duplicate availability zone name `#{duplicates.first.name}'"
        end

        parsed_availability_zones

      end

      def parse_networks(cloud_manifest, ip_provider_factory, global_network_resolver)
        networks = safe_property(cloud_manifest, 'networks', :class => Array)
        if networks.empty?
          raise DeploymentNoNetworks, 'No networks specified'
        end

        parsed_networks = networks.map do |network_spec|
          type = safe_property(network_spec, 'type', :class => String, :default => 'manual')

          case type
            when 'manual'
              ManualNetwork.new(network_spec, global_network_resolver, ip_provider_factory, @logger)
            when 'dynamic'
              DynamicNetwork.new(network_spec, @logger)
            when 'vip'
              VipNetwork.new(network_spec, @logger)
            else
              raise DeploymentInvalidNetworkType,
                "Invalid network type `#{type}'"
          end
        end

        duplicates = detect_duplicates(parsed_networks) { |network| network.canonical_name }
        unless duplicates.empty?
          raise DeploymentCanonicalNetworkNameTaken,"Invalid network name `#{duplicates.first.name}', canonical name already taken"
        end

        parsed_networks
      end

      def parse_compilation(cloud_manifest, networks)
        compilation_spec = safe_property(cloud_manifest, 'compilation', :class => Hash)
        config = CompilationConfig.new(compilation_spec)

        unless networks.any? { |network| network.name == config.network_name }
          raise CompilationConfigUnknownNetwork,
            "Compilation config references an unknown " +
              "network `#{config.network_name}'"
        end

        config
      end

      def parse_resource_pools(cloud_manifest)
        resource_pools = safe_property(cloud_manifest, 'resource_pools', :class => Array)
        if resource_pools.empty?
          raise DeploymentNoResourcePools, 'No resource_pools specified'
        end

        parsed_resource_pools = resource_pools.map do |rp_spec|
          ResourcePool.new(rp_spec, @logger)
        end


        duplicates = detect_duplicates(parsed_resource_pools) { |rp| rp.name }
        unless duplicates.empty?
          raise DeploymentDuplicateResourcePoolName, "Duplicate resource pool name `#{duplicates.first.name}'"
        end

        parsed_resource_pools
      end


      def parse_disk_pools(cloud_manifest)
        disk_pools = safe_property(cloud_manifest, 'disk_pools', :class => Array, :optional => true, :default => [])
        parsed_disk_pools = disk_pools.map do |dp_spec|
          DiskPool.parse(dp_spec)
        end


        duplicates = detect_duplicates(parsed_disk_pools) { |dp| dp.name }
        unless duplicates.empty?
          raise DeploymentDuplicateDiskPoolName, "Duplicate disk pool name `#{duplicates.first.name}'"
        end

        parsed_disk_pools
      end

      def detect_duplicates(collection, &iteratee)
        transformed_elements = Set.new
        duplicated_elements = Set.new
        collection.each do |element|
          transformed = iteratee.call(element)

          if transformed_elements.include?(transformed)
            duplicated_elements << element
          else
            transformed_elements << transformed
          end
        end

        duplicated_elements
      end
    end
  end
end
