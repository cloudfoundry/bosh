require 'bosh/template/property_helper'

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
        @job = Job.new(@deployment)

        parse_name
        parse_lifecycle

        parse_release
        parse_template
        parse_templates

        validate_templates

        check_template_uniqueness
        parse_disk
        parse_properties
        parse_resource_pool
        parse_update_config
        parse_instances
        parse_networks

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
            @job.templates << @job.release.use_template_named(template_name)
          end
        end
      end

      def parse_templates
        templates = safe_property(@job_spec, 'templates', class: Array, optional: true)

        if templates
          templates.each do |template|
            template_name = safe_property(template, 'name', class: String)
            release_name = safe_property(template, 'release', class: String, optional: true)

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

            @job.templates << release.use_template_named(template_name)
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

      def parse_instances
        @job.state = safe_property(@job_spec, "state", class: String, optional: true)
        job_size = safe_property(@job_spec, "instances", class: Integer)
        instance_states = safe_property(@job_spec, "instance_states", class: Hash, default: {})

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

        if @job.lifecycle == 'errand'
          @job.resource_pool.reserve_errand_capacity(job_size)
        else
          @job.resource_pool.reserve_capacity(job_size)
        end
        job_size.times do |index|
          @job.instances[index] = Instance.new(@job, index, @logger)
        end
      end

      def parse_networks
        @job.default_network = {}

        network_specs = safe_property(@job_spec, "networks", :class => Array)
        if network_specs.empty?
          raise JobMissingNetwork,
                "Job `#{@job.name}' must specify at least one network"
        end

        network_specs.each do |network_spec|
          network_name = safe_property(network_spec, "name", :class => String)
          network = @deployment.network(network_name)
          if network.nil?
            raise JobUnknownNetwork,
                  "Job `#{@job.name}' references an unknown network `#{network_name}'"
          end

          static_ips = nil
          if network_spec["static_ips"]
            static_ips = []
            each_ip(network_spec["static_ips"]) do |ip|
              static_ips << ip
            end
            if static_ips.size != @job.instances.size
              raise JobNetworkInstanceIpMismatch,
                    "Job `#{@job.name}' has #{@job.instances.size} instances but was allocated #{static_ips.size} static IPs"
            end
          end

          default_network = safe_property(network_spec, "default", :class => Array, :optional => true)
          if default_network
            default_network.each do |property|
              unless Network::VALID_DEFAULTS.include?(property)
                raise JobNetworkInvalidDefault,
                      "Job `#{@job.name}' specified an invalid default network property `#{property}', " +
                      "valid properties are: " + Network::VALID_DEFAULTS.join(", ")
              end

              if @job.default_network[property]
                raise JobNetworkMultipleDefaults,
                      "Job `#{@job.name}' specified more than one network to contain default #{property}"
              else
                @job.default_network[property] = network_name
              end
            end
          end

          @job.instances.each_with_index do |instance, index|
            reservation = NetworkReservation.new
            if static_ips
              reservation.ip = static_ips[index]
              reservation.type = NetworkReservation::STATIC
            else
              reservation.type = NetworkReservation::DYNAMIC
            end
            instance.add_network_reservation(network_name, reservation)
          end
        end

        if network_specs.size > 1
          missing_default_properties = Network::VALID_DEFAULTS.dup
          @job.default_network.each_key do |key|
            missing_default_properties.delete(key)
          end

          unless missing_default_properties.empty?
            raise JobNetworkMissingDefault,
                  "Job `#{@job.name}' must specify which network is default for " +
                  missing_default_properties.sort.join(", ") + ", since it has more than one network configured"
          end
        else
          # Set the default network to the one and only available network
          # (if not specified already)
          network = safe_property(network_specs[0], "name", :class => String)
          Network::VALID_DEFAULTS.each do |property|
            @job.default_network[property] ||= network
          end
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
    end
  end
end
