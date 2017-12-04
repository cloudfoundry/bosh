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

      attr_reader :vm_resources

      attr_reader :vm_extensions

      def initialize(compilation_config, azs_list, vm_types = [], vm_extensions = [])
        @workers = safe_property(compilation_config, 'workers', class: Integer, min: 1)

        @network_name = safe_property(compilation_config, 'network', class: String)

        @reuse_compilation_vms = safe_property(compilation_config,
          'reuse_compilation_vms',
          class: :boolean,
          optional: true)

        @cloud_properties = safe_property(compilation_config, 'cloud_properties', class: Hash, default: {})
        @env = safe_property(compilation_config, 'env', class: Hash, optional: true, default: {})

        parse_availability_zone(azs_list, compilation_config)

        parse_vm_type_and_vm_resources(compilation_config, vm_types)

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

      def parse_vm_type_and_vm_resources(compilation_config, vm_types)
        vm_type_name = safe_property(compilation_config, 'vm_type', class: String, optional: true)
        vm_resources = safe_property(compilation_config, 'vm_resources', class: Hash, optional: true)

        vm_configurations = [vm_type_name, vm_resources, @cloud_properties].reject { |v| v.nil? || v.empty? }.count

        if vm_configurations == 0
          raise Bosh::Director::CompilationConfigBadVmConfiguration,
            "Compilation config requires either 'vm_type', 'vm_resources', or 'cloud_properties', none given."
        end

        if vm_configurations > 1
          raise Bosh::Director::CompilationConfigBadVmConfiguration,
            "Compilation config specifies more than one of 'vm_type', 'vm_resources', or 'cloud_properties', only one is allowed."
        end

        if vm_type_name
          @vm_type = vm_types.find {|vm_type| vm_type.name == vm_type_name}

          if @vm_type.nil?
            vm_types_names = vm_types.map {|vm_type| vm_type.name}
            raise Bosh::Director::CompilationConfigInvalidVmType,
              "Compilation config references unknown vm type '#{vm_type_name}'. Known vm types are: #{vm_types_names.join(', ')}"
          end
        elsif vm_resources
          @vm_resources = Bosh::Director::DeploymentPlan::VmResources.new(vm_resources)
        end
      end

      def parse_vm_extensions(compilation_config, vm_extensions)
        @vm_extensions = []

        vm_extension_names = safe_property(compilation_config, 'vm_extensions', class: Array, optional: true)

        Array(vm_extension_names).each {|vm_extension_name|
          vm_extension = vm_extensions.find {|vm_extension| vm_extension.name == vm_extension_name}

          if vm_extension.nil?
            vm_extensions_names = vm_extensions.map {|vm_extension| vm_extension.name}
            raise Bosh::Director::CompilationConfigInvalidVmExtension,
              "Compilation config references unknown vm extension '#{vm_extension_name}'. Known vm extensions are: #{vm_extensions_names.join(', ')}"
          end

          if @vm_type.nil? && @vm_resources.nil?
            raise Bosh::Director::CompilationConfigBadVmConfiguration,
              "Compilation config is using vm extension '#{vm_extension.name}' and must configure a vm type or vm_resources block."
          end

          @vm_extensions.push(vm_extension)
        }
      end
    end
  end
end
