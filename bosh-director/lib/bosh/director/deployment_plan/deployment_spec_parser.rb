require 'common/deep_copy'

module Bosh::Director
  module DeploymentPlan
    class DeploymentSpecParser
      include DnsHelper
      include ValidationHelper

      def initialize(event_log)
        @event_log = event_log
      end

      # @param [Hash] manifest Raw deployment manifest
      # @return [DeploymentPlan::Planner] Deployment as build from deployment_spec
      def parse(manifest, options = {})
        @manifest = manifest

        @job_states = safe_property(options, 'job_states',
          :class => Hash, :default => {})

        @deployment = Planner.new(parse_name, options)

        parse_properties
        parse_releases
        parse_networks
        parse_compilation
        parse_update
        parse_resource_pools
        parse_jobs

        @deployment
      end

      private

      def parse_name
        safe_property(@manifest, 'name', :class => String)
      end

      def parse_properties
        @deployment.properties = safe_property(@manifest, 'properties',
          :class => Hash, :default => {})
      end

      def parse_releases
        release_specs = []

        if @manifest.has_key?('release')
          if @manifest.has_key?('releases')
            raise DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' " +
                'sections, please use one of the two.'
          end
          release_specs << @manifest['release']
        else
          safe_property(@manifest, 'releases', :class => Array).each do |release|
            release_specs << release
          end
        end

        release_specs.each do |release_spec|
          @deployment.add_release(ReleaseVersion.new(@deployment, release_spec))
        end
      end

      def parse_networks
        networks = safe_property(@manifest, 'networks', :class => Array)
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
        compilation_spec = safe_property(@manifest, 'compilation', :class => Hash)
        @deployment.compilation = CompilationConfig.new(@deployment, compilation_spec)
      end

      def parse_update
        update_spec = safe_property(@manifest, 'update', :class => Hash)
        @deployment.update = UpdateConfig.new(update_spec)
      end

      def parse_resource_pools
        resource_pools = safe_property(@manifest, 'resource_pools', :class => Array)
        resource_pools.each do |rp_spec|
          @deployment.add_resource_pool(ResourcePool.new(@deployment, rp_spec))
        end

        # Uncomment when integration test fixed
        # raise "No resource pools specified." if @resource_pools.empty?
      end

      def parse_jobs
        jobs = safe_property(@manifest, 'jobs', :class => Array, :default => [])
        jobs.each do |job_spec|
          state_overrides = @job_states[job_spec['name']]
          if state_overrides
            job_spec.recursive_merge!(state_overrides)
          end

          @deployment.add_job(Job.parse(@deployment, job_spec, @event_log))
        end
      end
    end
  end
end
