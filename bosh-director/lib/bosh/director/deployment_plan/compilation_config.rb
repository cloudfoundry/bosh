# Copyright (c) 2009-2012 VMware, Inc.

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

      # Creates compilation configuration spec from the deployment manifest.
      # @param [DeploymentPlan] deployment
      # @param [Hash] compilation_config parsed compilation config YAML section
      def initialize(compilation_config, azs_list = {})
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
      end

      def availability_zone_name
        @availability_zone.nil? ? nil : @availability_zone.name
      end
    end
  end
end
