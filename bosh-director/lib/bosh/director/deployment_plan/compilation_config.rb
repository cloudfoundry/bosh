# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeploymentPlan
    ##
    # Represents the deployment compilation worker configuration.
    class CompilationConfig
      include ValidationHelper

      # @return [DeploymentPlan] associated deployment
      attr_accessor :deployment

      # @return [Integer] number of worker VMs to use
      attr_accessor :workers

      # @return [DeploymentPlan::Network] network used by compilation workers
      attr_accessor :network

      # @return [Hash] cloud properties to use when creating VMs. (optional)
      attr_accessor :cloud_properties

      # @return [Hash] environment to use when creating VMs. (optional)
      attr_accessor :env

      # @return [Bool] if VMs should be reused for compilation tasks. (optional)
      attr_accessor :reuse_compilation_vms

      # Creates compilation configuration spec from the deployment manifest.
      # @param [DeploymentPlan] deployment
      # @param [Hash] compilation_config parsed compilation config YAML section
      def initialize(deployment, compilation_config)
        @deployment = deployment
        @workers = safe_property(compilation_config, "workers", class: Integer, min: 1)

        network_name = safe_property(compilation_config, "network", class: String)

        @reuse_compilation_vms = safe_property(compilation_config,
          "reuse_compilation_vms",
          class: :boolean,
          optional: true)

        @network = deployment.network(network_name)
        if @network.nil?
          raise CompilationConfigUnknownNetwork,
            "Compilation config references an unknown " +
              "network `#{network_name}'"
        end
        @cloud_properties = safe_property(
          compilation_config, "cloud_properties", class: Hash, default: {})
        @env = safe_property(compilation_config, "env", class: Hash, optional: true, default: {})
      end
    end
  end
end
