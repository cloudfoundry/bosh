# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class Job
      include Bosh::Common::PropertyHelper

      include IpUtil
      include DnsHelper
      include ValidationHelper

      # started, stopped and detached are real states
      # (persisting in DB and reflecting target instance state)
      # recreate and restart are two virtual states
      # (both set  target instance state to "started" and set
      # appropriate instance spec modifiers)
      VALID_JOB_STATES = %w(started stopped detached recreate restart)

      # @return [String] Job name
      attr_accessor :name

      # @return [String] Job canonical name (mostly for DNS)
      attr_accessor :canonical_name

      # @return [Integer] Persistent disk size (no disk if zero)
      attr_accessor :persistent_disk # TODO: rename to 'disk_size' (?)

      # @return [DeploymentPlan] Current deployment plan
      attr_accessor :deployment

      # @return [DeploymentPlan::Release] Release this job belongs to
      attr_accessor :release

      # @return [DeploymentPlan::ResourcePool] Resource pool this job should
      #   be run in
      attr_accessor :resource_pool

      # @return [DeploymentPlan::Network Job default network
      attr_accessor :default_network

      # @return [Array<DeploymentPlan::Template] Templates included into the job
      attr_accessor :templates

      # @return [Hash] Job properties
      attr_accessor :properties

      # @return [Hash<String, DeploymentPlan::Package] Packages included into
      #   this job
      attr_accessor :packages

      # @return [DeploymentPlan::UpdateConfig] Job update settings
      attr_accessor :update # TODO rename to update_config or update_settings

      # @return [Array<Models::Instance>] List of excess instance models that
      #   are not needed for current deployment
      attr_accessor :unneeded_instances

      # @return [String] Expected job state
      attr_accessor :state # TODO rename to avoid confusion

      # @return [Hash<Integer, String>] Individual instance expected states
      attr_accessor :instance_states

      # @return [Exception] Exception that requires job update process to be
      #   interrupted
      attr_accessor :halt_exception

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      # @param [Hash] job_spec Raw job spec from the deployment manifest
      # @return [Bosh::Director::DeploymentPlan::Job]
      def self.parse(deployment, job_spec)
        job = new(deployment, job_spec)
        job.parse
        job
      end

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      # @param [Hash] job_spec Raw job spec from the deployment manifest
      def initialize(deployment, job_spec)
        @deployment = deployment
        @job_spec = job_spec

        @release = nil
        @templates = []
        @all_properties = nil # All properties available to job
        @properties = nil # Actual job properties

        @error_mutex = Mutex.new
        @packages = {}
        @halt = false
        @unneeded_instances = []
      end

      def parse
        parse_name
        parse_release
        parse_template
        parse_disk
        parse_properties
        parse_resource_pool
        parse_update_config
        parse_instances
        parse_networks
      end

      def self.is_legacy_spec?(job_spec)
        !job_spec.has_key?("templates")
      end

      # Takes in a job spec and returns a job spec in the new format, if it
      # needs to be modified.  The new format has "templates" key, which is an
      # array with each template's data.  This is used for job collocation,
      # specifically for the agent's current job spec when compared to the
      # director's.  We only convert their template to a single array entry
      # because it should be impossible for the agent to have a job spec with
      # multiple templates in legacy form.
      def self.convert_from_legacy_spec(job_spec)
        return job_spec if !self.is_legacy_spec?(job_spec)
        template = {
          "name" => job_spec["template"],
          "version" => job_spec["version"],
          "sha1" => job_spec["sha1"],
          "blobstore_id" => job_spec["blobstore_id"]
        }
        job_spec["templates"] = [template]
      end

      # Returns job spec as a Hash. To be used by all instances of the job to
      # populate agent state.
      # @return [Hash] Hash representation
      def spec
        # TODO(lisbakke): Remove Legacy code when the agent has been updated
        # to accept templates as an array.
        first_template = @templates[0]
        result = {
          "name" => @name,
          "release" => @release.name,
          "templates" => [],
          # --- Legacy ---
          "template" => first_template.name,
          "version" => first_template.version,
          "sha1" => first_template.sha1,
          "blobstore_id" => first_template.blobstore_id
        }
        if first_template.logs
          result["logs"] = first_template.logs
        end
        # --- /Legacy ---

        @templates.each do |template|
          template_entry = {
            "name" => template.name,
            "version" => template.version,
            "sha1" => template.sha1,
            "blobstore_id" => template.blobstore_id
          }
          if template.logs
            template_entry["logs"] = template.logs
          end
          result["templates"] << template_entry
        end

        result
      end

      # Returns package specs for all packages in the job indexed by package
      # name. To be used by all instances of the job to populate agent state.
      # @return [Hash<String, Hash>] All package specs indexed by package name
      def package_spec
        result = {}
        @packages.each do |name, package|
          result[name] = package.spec
        end

        result.select { |name, _| run_time_dependencies.include? name }
      end

      # Returns all instances of this job
      # @return [Array<DeploymentPlan::Instance>] All job instances
      def instances
        @instances
      end

      # Returns job instance by index
      # @param [Integer] index
      # @return [DeploymentPlan::Instance] index-th instance
      def instance(index)
        @instances[index]
      end

      # Returns the state state of job instance by its index
      # @param [Integer] index Instance index
      # @return [String, nil] Instance state (nil if not specified)
      def instance_state(index)
        @instance_states[index] || @state
      end

      # Registers compiled package with this job.
      # @param [Models::CompiledPackage] compiled_package_model Compiled package
      # @return [void]
      def use_compiled_package(compiled_package_model)
        compiled_package = CompiledPackage.new(compiled_package_model)
        @packages[compiled_package.name] = compiled_package
      end

      def should_halt?
        @halt
      end

      def record_update_error(error, options = {})
        @error_mutex.synchronize do
          @halt = true
          @halt_exception = error
        end
      end

      def parse_name
        @name = safe_property(@job_spec, "name", :class => String)
        @canonical_name = canonical(@name)
      end

      def parse_release
        release_name = safe_property(@job_spec, "release", :class => String,
                                     :optional => true)

        if release_name.nil?
          if @deployment.releases.size == 1
            @release = @deployment.releases.first
          else
            raise JobMissingRelease,
                  "Cannot tell what release job `#{@name}' supposed to use, please reference an existing release"
          end
        else
          @release = @deployment.release(release_name)
        end

        if @release.nil?
          raise JobUnknownRelease,
                "Job `#{@name}' references an unknown release `#{release_name}'"
        end
      end

      def parse_template
        if @release.nil?
          raise DirectorError, "Cannot parse template before parsing release"
        end

        # TODO support plural "templates" syntax as well
        template_names = safe_property(@job_spec, "template")

        if template_names.is_a?(String)
          template_names = Array(template_names)
        end

        unless template_names.is_a?(Array)
          invalid_type("template", "String or Array", template_names)
        end

        template_names.each do |template_name|
          @release.use_template_named(template_name)
          @templates << @release.template(template_name)
        end
      end

      def parse_disk
        @persistent_disk = safe_property(@job_spec, "persistent_disk", :class => Integer, :default => 0)
      end

      def parse_properties
        # Manifest can contain global and per-job properties section
        job_properties = safe_property(@job_spec, "properties", :class => Hash, :optional => true)

        @all_properties = deployment.properties._deep_copy

        if job_properties
          @all_properties.recursive_merge!(job_properties)
        end

        mappings = safe_property(@job_spec, "property_mappings", :class => Hash, :default => {})

        mappings.each_pair do |to, from|
          resolved = lookup_property(@all_properties, from)

          if resolved.nil?
            raise JobInvalidPropertyMapping,
                  "Cannot satisfy property mapping `#{to}: #{from}', as `#{from}' is not in deployment properties"
          end

          @all_properties[to] = resolved
        end
      end

      def parse_resource_pool
        resource_pool_name = safe_property(@job_spec, "resource_pool",
                                           :class => String)
        @resource_pool = deployment.resource_pool(resource_pool_name)
        if @resource_pool.nil?
          raise JobUnknownResourcePool,
                "Job `#{@name}' references an unknown resource pool `#{resource_pool_name}'"
        end
      end

      def parse_update_config
        update_spec = safe_property(@job_spec, "update",
                                    :class => Hash, :optional => true)
        @update = UpdateConfig.new(update_spec, @deployment.update)
      end

      def parse_instances
        @instances = []
        @instance_states = {}

        @state = safe_property(@job_spec, "state",
                               :class => String, :optional => true)

        job_size = safe_property(@job_spec, "instances", :class => Integer)

        instance_states = safe_property(@job_spec, "instance_states",
                                        :class => Hash, :default => {})

        instance_states.each_pair do |index, state|
          begin
            index = Integer(index)
          rescue ArgumentError
            raise JobInvalidInstanceIndex,
                  "Invalid job index `#{index}', integer expected"
          end
          unless (0...job_size).include?(index)
            raise JobInvalidInstanceIndex,
                  "`#{@name}/#{index}' is outside of (0..#{job_size-1}) range"
          end
          unless VALID_JOB_STATES.include?(state)
            raise JobInvalidInstanceState,
                  "Invalid state `#{state}' for `#{@name}/#{index}', valid states are: #{VALID_JOB_STATES.join(", ")}"
          end
          @instance_states[index] = state
        end

        if @state && !VALID_JOB_STATES.include?(@state)
          raise JobInvalidJobState,
                "Invalid state `#{@state}' for `#{@name}', valid states are: #{VALID_JOB_STATES.join(", ")}"
        end

        job_size.times do |index|
          @instances[index] = Instance.new(self, index)
          @resource_pool.reserve_capacity(1)
        end
      end

      def parse_networks
        # TODO: refactor to make more readable
        @default_network = {}

        network_specs = safe_property(@job_spec, "networks", :class => Array)
        if network_specs.empty?
          raise JobMissingNetwork,
                "Job `#{@name}' must specify at least one network"
        end

        network_specs.each do |network_spec|
          network_name = safe_property(network_spec, "name", :class => String)
          network = @deployment.network(network_name)
          if network.nil?
            raise JobUnknownNetwork,
                  "Job `#{@name}' references an unknown network `#{network_name}'"
          end

          static_ips = nil
          if network_spec["static_ips"]
            static_ips = []
            each_ip(network_spec["static_ips"]) do |ip|
              static_ips << ip
            end
            if static_ips.size != @instances.size
              raise JobNetworkInstanceIpMismatch,
                    "Job `#{@name}' has #{@instances.size} instances but was allocated #{static_ips.size} static IPs"
            end
          end

          default_network = safe_property(network_spec, "default",
                                          :class => Array, :optional => true)
          if default_network
            default_network.each do |property|
              unless Network::VALID_DEFAULTS.include?(property)
                raise JobNetworkInvalidDefault,
                      "Job `#{@name}' specified an invalid default network property `#{property}', " +
                      "valid properties are: " + Network::VALID_DEFAULTS.join(", ")
              end

              if @default_network[property]
                raise JobNetworkMultipleDefaults,
                      "Job `#{@name}' specified more than one network to contain default #{property}"
              else
                @default_network[property] = network_name
              end
            end
          end

          @instances.each_with_index do |instance, index|
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
          @default_network.each_key do |key|
            missing_default_properties.delete(key)
          end
          unless missing_default_properties.empty?
            raise JobNetworkMissingDefault,
                  "Job `#{@name}' must specify which network is default for " +
                  missing_default_properties.sort.join(", ") + ", since it has more than one network configured"
          end
        else
          # Set the default network to the one and only available network
          # (if not specified already)
          network = safe_property(network_specs[0], "name", :class => String)
          Network::VALID_DEFAULTS.each do |property|
            @default_network[property] ||= network
          end
        end
      end

      # Extracts only the properties needed by this job. This is decoupled from
      # parsing properties because templates need to be bound to their models
      # before 'bind_properties' is being called (as we persist job template
      # property definitions in DB).
      def bind_properties
        @properties = filter_properties(@all_properties)
      end

      private

      # @param [Hash] collection All properties collection
      # @return [Hash] Properties required by templates included in this job
      def filter_properties(collection)
        if @templates.empty?
          raise DirectorError, "Can't extract job properties before parsing job templates"
        end

        return collection if @templates.none? { |template| template.properties }
        return extract_template_properties(collection) if @templates.all? { |template| template.properties }
        raise JobIncompatibleSpecs, "Job `#{name}' has specs with conflicting property definition styles between" +
            " its job spec templates.  This may occur if colocating jobs, one of which has a spec file including" +
            " `properties' and one which doesn't."
      end

      def extract_template_properties(collection)
        result = {}

        @templates.each do |template|
          template.properties.each_pair do |name, definition|
            copy_property(result, collection, name, definition["default"])
          end
        end

        result
      end

      def run_time_dependencies
        templates.flat_map { |template| template.package_models }.uniq.map(&:name)
      end
    end
  end
end
