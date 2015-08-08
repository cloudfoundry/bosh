require 'common/deep_copy'
require 'bosh/template/property_helper'
require 'bosh/director/deployment_plan/job_network_parser'
require 'bosh/director/deployment_plan/job_availability_zone_parser'
require 'bosh/director/deployment_plan/availability_zone_picker'

module Bosh::Director
  module DeploymentPlan
    class JobSpecParser
      include DnsHelper
      include ValidationHelper
      include Bosh::Template::PropertyHelper
      include IpUtil

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      def initialize(deployment, event_log, logger)
        @deployment = deployment
        @event_log = event_log
        @logger = logger
      end

      # @param [Hash] job_spec Raw job spec from the deployment manifest
      # @return [DeploymentPlan::Job] Job as build from job_spec
      def parse(job_spec)
        @job_spec = job_spec
        @job = Job.new(@deployment, @logger)

        parse_name
        parse_lifecycle

        parse_release
        validate_templates

        parse_template
        parse_templates

        check_template_uniqueness
        parse_disk
        parse_properties
        parse_resource_pool
        parse_update_config
        networks = JobNetworksParser.new(Network::VALID_DEFAULTS).parse(@job_spec, @job, @deployment)
        @job.networks = networks
        assign_default_networks(networks)

        availability_zones = JobAvilabilityZoneParser.new.parse(@job_spec, @job, @deployment, networks)
        @job.availability_zones = availability_zones

        desired_instances = parse_desired_instances(availability_zones, networks)
        @job.desired_instances = desired_instances

        @job
      end

      private

      def parse_name
        @job.name = safe_property(@job_spec, "name", :class => String)
        @job.canonical_name = canonical(@job.name)
      end

      def parse_lifecycle
        lifecycle = safe_property(@job_spec, "lifecycle",
          :class => String,
          :optional => true,
          :default => Job::DEFAULT_LIFECYCLE_PROFILE,
        )

        unless Job::VALID_LIFECYCLE_PROFILES.include?(lifecycle)
          raise JobInvalidLifecycle,
            "Invalid lifecycle `#{lifecycle}' for `#{@job.name}', " +
            "valid lifecycle profiles are: #{Job::VALID_LIFECYCLE_PROFILES.join(', ')}"
        end

        @job.lifecycle = lifecycle
      end

      def parse_release
        release_name = safe_property(@job_spec, "release", :class => String, :optional => true)

        if release_name.nil?
          if @deployment.releases.size == 1
            @job.release = @deployment.releases.first
          end
        else
          @job.release = @deployment.release(release_name)

          if @job.release.nil?
            raise JobUnknownRelease,
                  "Job `#{@job.name}' references an unknown release `#{release_name}'"
          end
        end
      end

      def parse_template
        template_names = safe_property(@job_spec, "template", optional: true)
        if template_names
          if template_names.is_a?(Array)
            @event_log.warn_deprecated(
              "Please use `templates' when specifying multiple templates for a job. " +
              "`template' for multiple templates will soon be unsupported."
            )
          end

          unless template_names.is_a?(Array) || template_names.is_a?(String)
            invalid_type("template", "String or Array", template_names)
          end

          unless @job.release
            raise JobMissingRelease, "Cannot tell what release job `#{@job.name}' is supposed to use, please explicitly specify one"
          end

          Array(template_names).each do |template_name|
            @job.templates << @job.release.get_or_create_template(template_name)
          end
        end
      end

      def parse_templates
        templates = safe_property(@job_spec, 'templates', class: Array, optional: true)

        if templates
          templates.each do |template_spec|
            template_name = safe_property(template_spec, 'name', class: String)
            release_name = safe_property(template_spec, 'release', class: String, optional: true)

            release = nil

            if release_name
              release = @deployment.release(release_name)
              unless release
                raise JobUnknownRelease,
                      "Template `#{template_name}' (job `#{@job.name}') references an unknown release `#{release_name}'"
              end
            else
              release = @job.release
              unless release
                raise JobMissingRelease, "Cannot tell what release template `#{template_name}' (job `#{@job.name}') is supposed to use, please explicitly specify one"
              end
            end

            @job.templates << release.get_or_create_template(template_name)

            links = safe_property(template_spec, 'links', class: Hash, optional: true)
            @logger.debug("Parsing template links: #{links.inspect}")

            links.to_a.each do |name, path|
              link_path = LinkPath.parse(@deployment.name, path, @logger)
              @job.add_link_path(template_name, name, link_path)
            end
          end
        end
      end

      def check_template_uniqueness
        all_names = @job.templates.map(&:name)
        @job.templates.each do |template|
          if all_names.count(template.name) > 1
            raise JobInvalidTemplates,
                  "Colocated job template `#{template.name}' has the same name in multiple releases. " +
                  "BOSH cannot currently colocate two job templates with identical names from separate releases."
          end
        end
      end

      def parse_disk
        disk_size = safe_property(@job_spec, 'persistent_disk', :class => Integer, :optional => true)
        disk_pool_name = safe_property(@job_spec, 'persistent_disk_pool', :class => String, :optional => true)

        if disk_size && disk_pool_name
          raise JobInvalidPersistentDisk,
            "Job `#{@job.name}' references both a peristent disk size `#{disk_size}' " +
              "and a peristent disk pool `#{disk_pool_name}'"
        end

        if disk_size
          if disk_size < 0
            raise JobInvalidPersistentDisk,
              "Job `#{@job.name}' references an invalid peristent disk size `#{disk_size}'"
          else
            @job.persistent_disk = disk_size
          end
        end

        if disk_pool_name
          disk_pool = @deployment.disk_pool(disk_pool_name)
          if disk_pool.nil?
            raise JobUnknownDiskPool,
                  "Job `#{@job.name}' references an unknown disk pool `#{disk_pool_name}'"
          else
            @job.persistent_disk_pool = disk_pool
          end
        end
      end

      def parse_properties
        # Manifest can contain global and per-job properties section
        job_properties = safe_property(@job_spec, "properties", :class => Hash, :optional => true, :default => {})

        @job.all_properties = @deployment.properties.recursive_merge(job_properties)

        mappings = safe_property(@job_spec, "property_mappings", :class => Hash, :default => {})

        mappings.each_pair do |to, from|
          resolved = lookup_property(@job.all_properties, from)

          if resolved.nil?
            raise JobInvalidPropertyMapping,
                  "Cannot satisfy property mapping `#{to}: #{from}', as `#{from}' is not in deployment properties"
          end

          @job.all_properties[to] = resolved
        end
      end

      def parse_resource_pool
        resource_pool_name = safe_property(@job_spec, "resource_pool", class: String)
        @job.resource_pool = @deployment.resource_pool(resource_pool_name)
        if @job.resource_pool.nil?
          raise JobUnknownResourcePool,
                "Job `#{@job.name}' references an unknown resource pool `#{resource_pool_name}'"
        end
      end

      def parse_update_config
        update_spec = safe_property(@job_spec, "update", class: Hash, optional: true)
        @job.update = UpdateConfig.new(update_spec, @deployment.update)
      end

      def parse_desired_instances(availability_zones, networks)
        @job.state = safe_property(@job_spec, "state", class: String, optional: true)
        job_size = safe_property(@job_spec, "instances", class: Integer)
        instance_states = safe_property(@job_spec, "instance_states", class: Hash, default: {})

        networks.each do |network|
          static_ips = network.static_ips
          if static_ips && static_ips.size != job_size
            raise JobNetworkInstanceIpMismatch,
              "Job `#{@job.name}' has #{job_size} instances but was allocated #{static_ips.size} static IPs"
          end
        end

        instance_states.each_pair do |index, state|
          begin
            index = Integer(index)
          rescue ArgumentError
            raise JobInvalidInstanceIndex,
              "Invalid job index `#{index}', integer expected"
          end

          unless (0...job_size).include?(index)
            raise JobInvalidInstanceIndex,
              "`#{@job.name}/#{index}' is outside of (0..#{job_size-1}) range"
          end

          unless Job::VALID_JOB_STATES.include?(state)
            raise JobInvalidInstanceState,
              "Invalid state `#{state}' for `#{@job.name}/#{index}', valid states are: #{Job::VALID_JOB_STATES.join(", ")}"
          end

          @job.instance_states[index] = state
        end

        if @job.state && !Job::VALID_JOB_STATES.include?(@job.state)
          raise JobInvalidJobState,
            "Invalid state `#{@job.state}' for `#{@job.name}', valid states are: #{Job::VALID_JOB_STATES.join(", ")}"
        end

        job_size.times.map do |index|
          instance_state = @job.instance_state(index)
          DesiredInstance.new(@job, instance_state, @deployment)
        end
      end

      def validate_templates
        template_property = safe_property(@job_spec, 'template', optional: true)
        templates_property = safe_property(@job_spec, 'templates', optional: true)

        if template_property && templates_property
          raise JobInvalidTemplates,
                "Job `#{@job.name}' specifies both template and templates keys, only one is allowed"
        end

        if [template_property, templates_property].compact.empty?
          raise ValidationMissingField,
                "Job `#{@job.name}' does not specify template or templates keys, one is required"
        end
      end

      def assign_default_networks(networks)
        Network::VALID_DEFAULTS.each do |property|
          @job.default_network[property] = networks.find {|network| network.default_for?(property) }
        end
      end
    end
  end
end
