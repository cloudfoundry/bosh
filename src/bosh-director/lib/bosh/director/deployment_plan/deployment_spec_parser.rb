module Bosh::Director
  module DeploymentPlan
    class DeploymentSpecParser
      include ValidationHelper

      def initialize(deployment, event_log, logger)
        @event_log = event_log
        @logger = logger
        @deployment = deployment
      end

      # @param [Hash] manifest Raw deployment manifest
      # @return [DeploymentPlan::Planner] Deployment as build from deployment_spec
      def parse(deployment_interpolated_manifest, options = {})
        @deployment_manifest = deployment_interpolated_manifest
        @job_states = safe_property(options, 'job_states', :class => Hash, :default => {})

        parse_options = {}
        if options['canaries']
          parse_options['canaries'] = options['canaries']
          @logger.debug("Using canaries value #{options['canaries']} given in a command line.")
        end

        if options['max_in_flight']
          parse_options['max_in_flight'] = options['max_in_flight']
          @logger.debug("Using max_in_flight value #{options['max_in_flight']} given in a command line.")
        end

        parse_stemcells
        parse_properties
        parse_releases
        parse_update(parse_options)
        parse_instance_groups(parse_options)
        parse_variables
        parse_addons

        @deployment
      end

      private

      def parse_stemcells
        if @deployment_manifest.has_key?('stemcells')
          safe_property(@deployment_manifest, 'stemcells', :class => Array).each do |stemcell_hash|
            alias_val = safe_property(stemcell_hash, 'alias', :class => String)
            if @deployment.stemcells.has_key?(alias_val)
              raise StemcellAliasAlreadyExists, "Duplicate stemcell alias '#{alias_val}'"
            end
            @deployment.add_stemcell(Stemcell.parse(stemcell_hash))
          end
        end
      end

      def parse_properties
        @deployment.properties = safe_property(@deployment_manifest, 'properties',
          :class => Hash, :default => {})
      end

      def parse_addons
        @deployment.addons = Addon::Parser.new(@deployment.releases, @deployment_manifest, Addon::DEPLOYMENT_LEVEL).parse
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

      def parse_update(parse_options)
        update_spec = safe_property(@deployment_manifest, 'update', :class => Hash)
        @deployment.update = UpdateConfig.new(update_spec.merge(parse_options))
      end

      def parse_instance_groups(parse_options)
        if @deployment_manifest.has_key?('jobs') && @deployment_manifest.has_key?('instance_groups')
          raise JobBothInstanceGroupAndJob, "Deployment specifies both jobs and instance_groups keys, only one is allowed"
        end

        jobs = safe_property(@deployment_manifest, 'jobs', :class => Array, :default => [])
        instance_groups = safe_property(@deployment_manifest, 'instance_groups', :class => Array, :default => [])

        # FIX this, instance groups can be empty
        if !instance_groups.empty?
          jobs = instance_groups
        end

        jobs.each do |job_spec|
          # get state specific for this job or all jobs
          state_overrides = @job_states.fetch(job_spec['name'], @job_states.fetch('*', {}))
          job_spec = job_spec.recursive_merge(state_overrides)
          @deployment.add_instance_group(InstanceGroup.parse(@deployment, job_spec, @event_log, @logger, parse_options))
        end
      end

      def parse_variables
        variables_spec = safe_property(@deployment_manifest, 'variables', :class => Array, :default => [])
        @deployment.set_variables(VariablesSpecParser.new(@logger).parse(variables_spec))
      end
    end
  end
end
