require 'common/deep_copy'

module Bosh::Director
  module DeploymentPlan
    class JobSpecParser
      include DnsHelper
      include ValidationHelper
      include Bosh::Common::PropertyHelper
      include IpUtil

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      def initialize(deployment)
        @deployment = deployment
      end

      # @param [Hash] job_spec Raw job spec from the deployment manifest
      # @return [DeploymentPlan::Job] Job as build from job_spec
      def parse(job_spec)
        @job_spec = job_spec
        @job = Job.new(@deployment)

        parse_name
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

      def parse_release
        release_name = safe_property(@job_spec, "release", :class => String, :optional => true)

        if release_name.nil?
          if @deployment.releases.size == 1
            @job.release = @deployment.releases.first
          else
            raise JobMissingRelease,
                  "Cannot tell what release job `#{@job.name}' supposed to use, please reference an existing release"
          end
        else
          @job.release = @deployment.release(release_name)
        end

        if @job.release.nil?
          raise JobUnknownRelease,
                "Job `#{@job.name}' references an unknown release `#{release_name}'"
        end
      end

      def parse_template
        if @job.release.nil?
          raise DirectorError, "Cannot parse template before parsing release"
        end

        template_names = safe_property(@job_spec, "template", optional: true)
        if template_names
          if template_names.is_a?(String)
            template_names = Array(template_names)
          end

          unless template_names.is_a?(Array)
            invalid_type("template", "String or Array", template_names)
          end

          template_names.each do |template_name|
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

            release = release_name ? @deployment.release(release_name) : @job.release
            if release
              @job.templates << release.use_template_named(template_name)
            else
              raise JobUnknownRelease,
                    "Template `#{template_name}' (job `#{@job.name}') references an unknown release `#{release_name}'"
            end
          end
        end
      end

      def check_template_uniqueness
        if @job.templates.uniq(&:name).size != @job.templates.size
          raise JobInvalidTemplates,
                "Job `#{@job.name}' templates must not have repeating names."
        end

        if @job.templates.uniq(&:release).size > 1
          raise JobInvalidTemplates,
                "Job `#{@job.name}' templates must come from the same release."
        end
      end

      def parse_disk
        @job.persistent_disk = safe_property(@job_spec, "persistent_disk", :class => Integer, :default => 0)
      end

      def parse_properties
        # Manifest can contain global and per-job properties section
        job_properties = safe_property(@job_spec, "properties", :class => Hash, :optional => true)

        @job.all_properties = Bosh::Common::DeepCopy.copy(@deployment.properties)

        if job_properties
          @job.all_properties.recursive_merge!(job_properties)
        end

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

        job_size.times do |index|
          @job.instances[index] = Instance.new(@job, index)
          @job.resource_pool.reserve_capacity(1)
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
