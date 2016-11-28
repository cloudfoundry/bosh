module Bosh::Director
  module DeploymentPlan
    class CloudManifestParser
      include ValidationHelper
      include DuplicateDetector

      def initialize(logger)
        @logger = logger
      end

      def parse(cloud_manifest, global_network_resolver, ip_provider_factory)
        azs = parse_availability_zones(cloud_manifest)
        az_list = CloudPlanner.index_by_name(azs)
        networks = parse_networks(cloud_manifest, global_network_resolver, azs)
        resource_pools = parse_resource_pools(cloud_manifest)
        vm_types = parse_vm_types(cloud_manifest)
        vm_extensions = parse_vm_extensions(cloud_manifest)
        disk_types = parse_disk_types(cloud_manifest)
        compilation_config = parse_compilation(cloud_manifest, networks, az_list, vm_types, vm_extensions)

        CloudPlanner.new({
          availability_zones_list: az_list,
          networks: networks,
          global_network_resolver: global_network_resolver,
          ip_provider_factory: ip_provider_factory,
          compilation: compilation_config,
          resource_pools: resource_pools,
          vm_types: vm_types,
          vm_extensions: vm_extensions,
          disk_types: disk_types,
          logger: @logger,
        })
      end

      private

      def parse_availability_zones(cloud_manifest)
        availability_zones = safe_property(cloud_manifest, 'azs', :class => Array, :optional => true, :default => [])
        parsed_availability_zones = availability_zones.map do |availability_zone|
          AvailabilityZone.parse(availability_zone)
        end

        duplicates = detect_duplicates(parsed_availability_zones) { |az| az.name }
        unless duplicates.empty?
          raise DeploymentDuplicateAvailabilityZoneName, "Duplicate az name '#{duplicates.first.name}'"
        end

        parsed_availability_zones
      end

      def parse_networks(cloud_manifest, global_network_resolver, availability_zones)
        networks = safe_property(cloud_manifest, 'networks', :class => Array)
        if networks.empty?
          raise DeploymentNoNetworks, 'No networks specified'
        end

        parsed_networks = networks.map do |network_spec|
          type = safe_property(network_spec, 'type', :class => String, :default => 'manual')

          case type
            when 'manual'
              ManualNetwork.parse(network_spec, availability_zones, global_network_resolver, @logger)
            when 'dynamic'
              DynamicNetwork.parse(network_spec, availability_zones, @logger)
            when 'vip'
              VipNetwork.new(network_spec, @logger)
            else
              raise DeploymentInvalidNetworkType,
                "Invalid network type '#{type}'"
          end
        end

        duplicates = detect_duplicates(parsed_networks) { |network| network.canonical_name }
        unless duplicates.empty?
          raise DeploymentCanonicalNetworkNameTaken, "Invalid network name '#{duplicates.first.name}', canonical name already taken"
        end

        parsed_networks
      end

      def parse_compilation(cloud_manifest, networks, az_list, vm_types, vm_extensions)
        compilation_spec = safe_property(cloud_manifest, 'compilation', :class => Hash)
        config = CompilationConfig.new(compilation_spec, az_list, vm_types, vm_extensions)

        compilation_network = networks.find { |network| network.name == config.network_name }
        if compilation_network.nil?
          raise CompilationConfigUnknownNetwork,
            "Compilation config references an unknown " +
              "network '#{config.network_name}'"
        end

        unless compilation_network.has_azs?([config.availability_zone_name])
          raise JobNetworkMissingRequiredAvailabilityZone,
            "Compilation config refers to az '#{config.availability_zone_name}' but network '#{compilation_network.name}' has no matching subnet(s)."
        end

        config
      end

      def parse_resource_pools(cloud_manifest)
        resource_pools = safe_property(cloud_manifest, 'resource_pools', :class => Array, optional: true)

        if resource_pools.nil?
          return {}
        end

        if resource_pools.empty?
          raise DeploymentNoResourcePools, 'No resource_pools specified'
        end

        parsed_resource_pools = resource_pools.map do |rp_spec|
          ResourcePool.new(rp_spec)
        end

        duplicates = detect_duplicates(parsed_resource_pools) { |rp| rp.name }
        unless duplicates.empty?
          raise DeploymentDuplicateResourcePoolName, "Duplicate resource pool name '#{duplicates.first.name}'"
        end

        parsed_resource_pools
      end

      def parse_vm_types(cloud_manifest)
        vm_types = safe_property(cloud_manifest, 'vm_types', :class => Array, :optional => true, :default => [])

        parsed_vm_types = vm_types.map do |vmt_spec|
          VmType.new(vmt_spec)
        end

        duplicates = detect_duplicates(parsed_vm_types) { |vmt| vmt.name }
        unless duplicates.empty?
          raise DeploymentDuplicateVmTypeName, "Duplicate vm type name '#{duplicates.first.name}'"
        end

        parsed_vm_types
      end

      def parse_vm_extensions(cloud_manifest)
        vm_extensions = safe_property(cloud_manifest, 'vm_extensions', :class => Array, :optional => true, :default => [])

        parsed_vm_extensions = vm_extensions.map do |vmt_spec|
          VmExtension.new(vmt_spec)
        end

        duplicates = detect_duplicates(parsed_vm_extensions) { |vmt| vmt.name }
        unless duplicates.empty?
          raise DeploymentDuplicateVmExtensionName, "Duplicate vm extension name '#{duplicates.first.name}'"
        end

        parsed_vm_extensions
      end

      def parse_disk_types(cloud_manifest)
        disk_pools = safe_property(cloud_manifest, 'disk_pools', :class => Array, :optional => true, :default => [])
        disk_types = safe_property(cloud_manifest, 'disk_types', :class => Array, :optional => true, :default => [])

        if disk_pools.any? && disk_types.any?
          raise DeploymentInvalidDiskSpecification, "Both 'disk_types' and 'disk_pools' are specified, only one key is allowed. 'disk_pools' key will be DEPRECATED in the future."
        end

        disk_names = []

        if disk_pools.any?
          disk_source = 'pool'
          disk_names = disk_pools
        elsif disk_types.any?
          disk_source = 'type'
          disk_names = disk_types
        end

        parsed_disk_types = disk_names.map do |dp_spec|
          DiskType.parse(dp_spec)
        end


        duplicates = detect_duplicates(parsed_disk_types) { |dp| dp.name }
        unless duplicates.empty?
          raise DeploymentDuplicateDiskTypeName, "Duplicate disk #{disk_source} name '#{duplicates.first.name}'"
        end

        parsed_disk_types
      end
    end
  end
end
