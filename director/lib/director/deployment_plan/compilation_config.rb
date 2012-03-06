# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    ##
    # Represents the deployment complication worker configuration.
    class CompilationConfig
      include ValidationHelper

      # @return [DeploymentPlan] associated deployment
      attr_accessor :deployment

      # @return [Integer] number of worker VMs to use
      attr_accessor :workers

      # @return [NetworkSpec] network to use for compilation workers
      attr_accessor :network

      # @return [Hash] cloud properties to use when creating VMs. (optional)
      attr_accessor :cloud_properties

      # @return [Hash] environment to use when creating VMs. (optional)
      attr_accessor :env

      ##
      # Creates compilation configuration spec from the deployment manifest.
      # @param [DeploymentPlan] deployment
      # @param [Hash] compilation_config parsed compilation config YAML section
      def initialize(deployment, compilation_config)
        @deployment = deployment
        @workers = safe_property(compilation_config, "workers",
                                 :class => Integer)
        network_name = safe_property(compilation_config, "network",
                                     :class => String)
        @network = deployment.network(network_name)
        if @network.nil?
          raise "Compilation workers reference an unknown " +
                    "network: '#{network_name}'"
        end
        @cloud_properties = safe_property(
            compilation_config, "cloud_properties", :class => Hash)
        @env = safe_property(compilation_config, "env", :class => Hash,
                             :optional => true, :default => {})
      end
    end
  end
end
