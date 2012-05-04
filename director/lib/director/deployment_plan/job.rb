# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    class JobSpec
      include IpUtil
      include DnsHelper
      include ValidationHelper

      # started, stopped and detached are real states
      # (persisting in DB and reflecting target instance state)
      # recreate and restart are two virtual states
      # (both set  target instance state to "started" and set
      # appropriate instance spec modifiers)
      VALID_JOB_STATES = %w(started stopped detached recreate restart)

      attr_accessor :deployment
      attr_accessor :release
      attr_accessor :name
      attr_accessor :canonical_name
      attr_accessor :persistent_disk # TODO: rename to 'disk_size' (?)
      attr_accessor :resource_pool
      attr_accessor :default_network
      attr_accessor :template
      attr_accessor :properties
      attr_accessor :packages
      attr_accessor :update
      attr_accessor :unneeded_instances
      attr_accessor :state
      attr_accessor :instance_states
      attr_accessor :halt_exception

      # @param [Bosh::Director::DeploymentPlan] deployment Deployment plan
      # @param [Hash] job_spec Raw job spec from the deployment manifest
      def initialize(deployment, job_spec)
        @deployment = deployment
        @job_spec = job_spec

        parse_name
        parse_release
        parse_template
        parse_disk
        parse_properties
        parse_resource_pool
        parse_update_config
        parse_instances
        parse_networks

        @error_mutex = Mutex.new
        @packages = {}
        @halt = false
        @unneeded_instances = []
      end

      # @return [Hash] Hash representation
      def spec
        result = {
          "name" => @name,
          "release" => @release.name,
          "template" => @template.template.name,
          "version" => @template.template.version,
          "sha1" => @template.template.sha1,
          "blobstore_id" => @template.template.blobstore_id,
        }

        # TODO: refactor as a part of 'spec vs model' refactoring
        if @template.template.logs
          result["logs"] = @template.template.logs
        end

        result
      end

      def instances
        @instances
      end

      def instance(index)
        @instances[index]
      end

      def add_package(package, compiled_package)
        @packages[package.name] = PackageSpec.new(package, compiled_package)
      end

      def package_spec
        result = {}
        @packages.each do |name, package|
          result[name] = package.spec
        end
        result
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

      private

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
            raise ArgumentError, "Cannot tell what release job '#{@name}' " +
              "supposed to use, please reference an existing release"
          end
        else
          @release = @deployment.release(release_name)
        end

        if @release.nil?
          raise ArgumentError, "Job '#{@name}' references " +
            "an unknown release '#{release_name}'"
        end
      end

      def parse_template
        template_name = safe_property(@job_spec, "template", :class => String)
        @template = @release.template(template_name)
      end

      def parse_disk
        @persistent_disk = safe_property(@job_spec, "persistent_disk",
                                         :class => Integer, :default => 0)
      end

      def parse_properties
        job_properties = safe_property(@job_spec, "properties", :class => Hash,
                                       :optional => true)
        if job_properties.nil?
          @properties = deployment.properties
        else
          @properties = deployment.properties._deep_copy
          @properties.recursive_merge!(job_properties)
        end
      end

      def parse_resource_pool
        resource_pool_name = safe_property(@job_spec, "resource_pool",
                                           :class => String)
        @resource_pool = deployment.resource_pool(resource_pool_name)
        if @resource_pool.nil?
          raise ArgumentError, "Job '#{@name}' references " +
            "an unknown resource pool '#{resource_pool_name}'"
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
            raise "Invalid index value: #{index}, integer expected"
          end
          unless (0...job_size).include?(index)
            raise ArgumentError, "Job '#{@name}' instance state '#{index}' " +
              "is outside of (0..#{job_size-1}) range"
          end
          unless VALID_JOB_STATES.include?(state)
            raise ArgumentError, "Job '#{@name}' instance '#{index}' " +
              "has an unknown state '#{state}', " +
              "valid states are: #{VALID_JOB_STATES.join(", ")}"
          end
          @instance_states[index] = state
        end

        if @state && !VALID_JOB_STATES.include?(@state)
          raise ArgumentError, "Job '#{@name}' " +
            "has an unknown state '#{@state}', " +
            "valid states are: #{VALID_JOB_STATES.join(", ")}"
        end

        job_size.times do |index|
          @instances[index] = InstanceSpec.new(self, index)
          @resource_pool.reserve_vm
        end
      end

      def parse_networks
        # TODO: refactor to make more readable
        @default_network = {}

        network_specs = safe_property(@job_spec, "networks", :class => Array)
        if network_specs.empty?
          raise ArgumentError, "Job '#{@name}' must specify " +
            "at least one network"
        end

        network_specs.each do |network_spec|
          network_name = safe_property(network_spec, "name", :class => String)
          network = @deployment.network(network_name)
          if network.nil?
            raise ArgumentError, "Job '#{@name}' references " +
              "an unknown network '#{network_name}'"
          end

          static_ips = nil
          if network_spec["static_ips"]
            static_ips = []
            each_ip(network_spec["static_ips"]) do |ip|
              static_ips << ip
            end
            if static_ips.size != @instances.size
              raise ArgumentError, "Job '#{@name}' has #{@instances.size} " +
                "instances but was allocated #{static_ips.size} static IPs"
            end
          end

          default_network = safe_property(network_spec, "default",
                                          :class => Array, :optional => true)
          if default_network
            default_network.each do |property|
              unless NetworkSpec::VALID_DEFAULTS.include?(property)
                raise ArgumentError, "Job '#{@name}' specified " +
                  "an invalid default property: #{property}"
              end

              if @default_network[property]
                raise ArgumentError, "Job '#{@name}' must specify " +
                  "only one default network for: #{property}"
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
          missing_default_properties = NetworkSpec::VALID_DEFAULTS.dup
          @default_network.each_key do |key|
            missing_default_properties.delete(key)
          end
          unless missing_default_properties.empty?
            raise ArgumentError, "Job '#{@name}' must specify " +
              "a default network for " +
              "'#{missing_default_properties.sort.join(", ")}' " +
              "since it has more than one network configured"
          end
        else
          # Set the default network to the one and only available network
          # (if not specified already)
          network = safe_property(network_specs[0], "name", :class => String)
          NetworkSpec::VALID_DEFAULTS.each do |property|
            @default_network[property] ||= network
          end
        end
      end
    end
  end
end