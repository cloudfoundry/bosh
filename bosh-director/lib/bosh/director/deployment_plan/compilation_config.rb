module Bosh::Director
  module DeploymentPlan
    ##
    # Represents the deployment compilation worker configuration.
    class CompilationConfig
      include ValidationHelper

      # @return [Integer] number of worker VMs to use
      attr_accessor :workers

      # @return [Hash] cloud properties to use when creating VMs. (optional)
      attr_accessor :cloud_properties

      # @return [Hash] environment to use when creating VMs. (optional)
      attr_accessor :env

      # @return [Bool] if VMs should be reused for compilation tasks. (optional)
      attr_accessor :reuse_compilation_vms

      attr_reader :network_name

      attr_reader :availability_zone

      attr_reader :vm_type

      def initialize(compilation_config, azs_list, vm_types = [])
        @workers = safe_property(compilation_config, 'workers', class: Integer, min: 1)

        @network_name = safe_property(compilation_config, 'network', class: String)

        @reuse_compilation_vms = safe_property(compilation_config,
          'reuse_compilation_vms',
          class: :boolean,
          optional: true)

        @cloud_properties = safe_property(
          compilation_config, 'cloud_properties', class: Hash, default: {})
        @env = safe_property(compilation_config, 'env', class: Hash, optional: true, default: {})

        az_name = safe_property(compilation_config, 'az', class: String, optional: true)
        @availability_zone = azs_list[az_name]
        if az_name && !az_name.empty? && @availability_zone.nil?
          raise Bosh::Director::CompilationConfigInvalidAvailabilityZone,
            "Compilation config references unknown az '#{az_name}'. Known azs are: [#{azs_list.keys.join(', ')}]"
        end

        vm_type_name = safe_property(compilation_config, 'vm_type', class: String, optional: true)

        if vm_type_name
          @vm_type = vm_types.find { |vm_type| vm_type.name == vm_type_name }

          if @vm_type.nil?
            vm_types_names = vm_types.map { |vm_type| vm_type.name }
            raise Bosh::Director::CompilationConfigInvalidVmType,
              "Compilation config references unknown vm type '#{vm_type_name}'. Known vm types are: #{vm_types_names.join(', ')}"
          end

          unless @cloud_properties.empty?
            raise Bosh::Director::CompilationConfigCloudPropertiesNotAllowed,
              "Compilation config is using vm type '#{@vm_type.name}' and should not be configuring cloud_properties."
          end
        end
      end

      def availability_zone_name
        @availability_zone.nil? ? nil : @availability_zone.name
      end
    end
  end
end
