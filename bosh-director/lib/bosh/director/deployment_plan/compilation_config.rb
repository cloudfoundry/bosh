module Bosh::Director
  module DeploymentPlan
    ##
    # Represents the deployment compilation worker configuration.
    class CompilationConfig
      include ValidationHelper

      # @return [Integer] number of worker VMs to use
      attr_accessor :workers

      # @return [Hash] cloud properties to use when creating VMs. (optional)
      attr_reader :cloud_properties

      # @return [Hash] environment to use when creating VMs. (optional)
      attr_accessor :env

      # @return [Bool] if VMs should be reused for compilation tasks. (optional)
      attr_accessor :reuse_compilation_vms

      attr_reader :network_name

      attr_reader :availability_zone

      attr_reader :vm_type

      attr_reader :vm_extensions

      def initialize(compilation_config, azs_list, vm_types = [], vm_extensions = [])
        @workers = safe_property(compilation_config, 'workers', class: Integer, min: 1)

        @network_name = safe_property(compilation_config, 'network', class: String)

        @reuse_compilation_vms = safe_property(compilation_config,
          'reuse_compilation_vms',
          class: :boolean,
          optional: true)

        @cloud_properties = safe_property(
          compilation_config, 'cloud_properties', class: Hash, default: {})
        @env = safe_property(compilation_config, 'env', class: Hash, optional: true, default: {})

        parse_availability_zone(azs_list, compilation_config)

        parse_vm_type(compilation_config, vm_types)

        parse_vm_extensions(compilation_config, vm_extensions)

      end

      def availability_zone_name
        @availability_zone.nil? ? nil : @availability_zone.name
      end

      private

      def parse_availability_zone(azs_list, compilation_config)
        az_name = safe_property(compilation_config, 'az', class: String, optional: true)
        @availability_zone = azs_list[az_name]
        if az_name && !az_name.empty? && @availability_zone.nil?
          raise Bosh::Director::CompilationConfigInvalidAvailabilityZone,
                "Compilation config references unknown az '#{az_name}'. Known azs are: [#{azs_list.keys.join(', ')}]"
        end
      end

      def parse_vm_type(compilation_config, vm_types)
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

      def parse_vm_extensions(compilation_config, vm_extensions)
        @vm_extensions = []

        vm_extension_names = safe_property(compilation_config, 'vm_extensions', class: Array, optional: true)
        Array(vm_extension_names).each { |vm_extension_name|
          vm_extension = vm_extensions.find { |vm_extension| vm_extension.name == vm_extension_name }

          if vm_extension.nil?
            vm_extensions_names = vm_extensions.map { |vm_extension| vm_extension.name }
            raise Bosh::Director::CompilationConfigInvalidVmExtension,
                  "Compilation config references unknown vm extension '#{vm_extension_name}'. Known vm extensions are: #{vm_extensions_names.join(', ')}"
          end

          if @vm_type.nil?
            raise Bosh::Director::CompilationConfigVmTypeRequired,
                  "Compilation config is using vm extension '#{vm_extension.name}' and must configure a vm type."
          end

          @vm_extensions.push(vm_extension)
        }
      end
    end
  end
end
