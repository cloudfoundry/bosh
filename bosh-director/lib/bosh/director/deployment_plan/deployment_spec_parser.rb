module Bosh::Director
  module DeploymentPlan
    class DeploymentSpecParser
      include DnsHelper
      include ValidationHelper

      def initialize(deployment, event_log, logger)
        @event_log = event_log
        @logger = logger
        @deployment = deployment
      end

      # @param [Hash] manifest Raw deployment manifest
      # @return [DeploymentPlan::Planner] Deployment as build from deployment_spec
      def parse(deployment_manifest, options = {})
        @deployment_manifest = deployment_manifest
        @job_states = safe_property(options, 'job_states', :class => Hash, :default => {})

        parse_properties
        parse_releases
        parse_update
        parse_jobs

        @deployment
      end

      private

      def parse_name
        safe_property(@deployment_manifest, 'name', :class => String)
      end

      def parse_properties
        @deployment.properties = safe_property(@deployment_manifest, 'properties',
          :class => Hash, :default => {})
      end

      def parse_releases
        release_specs = []

        if @deployment_manifest.has_key?('release')
          if @deployment_manifest.has_key?('releases')
            raise DeploymentAmbiguousReleaseSpec,
              "Deployment manifest contains both 'release' and 'releases' " +
                'sections, please use one of the two.'
          end
          release_specs << @deployment_manifest['release']
        else
          safe_property(@deployment_manifest, 'releases', :class => Array).each do |release|
            release_specs << release
          end
        end

        release_specs.each do |release_spec|
          @deployment.add_release(ReleaseVersion.new(@deployment.model, release_spec))
        end
      end

      def parse_update
        update_spec = safe_property(@deployment_manifest, 'update', :class => Hash)
        @deployment.update = UpdateConfig.new(update_spec)
      end

      def parse_jobs
        jobs = safe_property(@deployment_manifest, 'jobs', :class => Array, :default => [])
        jobs.each do |job_spec|
          state_overrides = @job_states.fetch(job_spec['name'], {})
          job_spec = job_spec.recursive_merge(state_overrides)
          @deployment.add_job(Job.parse(@deployment, job_spec, @event_log, @logger))
        end
      end
    end
  end
end
