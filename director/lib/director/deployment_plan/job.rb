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
      # (both set  target instance state to "started" and set appropriate instance spec modifiers)
      VALID_JOB_STATES = %w(started stopped detached recreate restart)

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :canonical_name
      attr_accessor :persistent_disk
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

      # @param deployment DeploymentSpec
      # @param job Hash
      def initialize(deployment, job)
        @deployment = deployment
        @name = safe_property(job, "name", :class => String)
        @canonical_name = canonical(@name)
        @template = deployment.template(safe_property(job, "template", :class => String))
        @error_mutex = Mutex.new

        @persistent_disk = safe_property(job, "persistent_disk", :class => Integer, :default => 0)

        @instances = []
        @packages = {}
        @instance_states = { }

        properties = safe_property(job, "properties", :class => Hash, :optional => true)
        if properties.nil?
          @properties = deployment.properties
        else
          @properties = deployment.properties._deep_copy
          @properties.recursive_merge!(properties)
        end

        @resource_pool = deployment.resource_pool(safe_property(job, "resource_pool", :class => String))
        if @resource_pool.nil?
          raise ArgumentError, "Job #{@name} references an unknown resource pool: #{job["resource_pool"]}"
        end

        @update = UpdateConfig.new(safe_property(job, "update", :class => Hash, :optional => true), deployment.update)

        @halt = false
        @unneeded_instances = []
        @default_network = {}

        @state = safe_property(job, "state", :class => String, :optional => true)
        job_size = safe_property(job, "instances", :class => Integer)
        instance_states = safe_property(job, "instance_states", :class => Hash, :default => { })

        instance_states.each_pair do |index, state|
          begin
            index = Integer(index)
          rescue ArgumentError
            raise "Invalid index value: #{index}, integer expected"
          end
          unless (0...job_size).include?(index)
            raise ArgumentError, "Job '#{@name}' instance state '#{index}' is outside of (0..#{job_size-1}) range"
          end
          unless VALID_JOB_STATES.include?(state)
            raise ArgumentError, "Job '#{@name}' instance '#{index}' has an unknown state '#{state}', " +
                "valid states are: #{VALID_JOB_STATES.join(", ")}"
          end
          @instance_states[index] = state
        end

        if @state && !VALID_JOB_STATES.include?(@state)
          raise ArgumentError, "Job '#{@name}' has an unknown state '#{@state}', " +
              "valid states are: #{VALID_JOB_STATES.join(", ")}"
        end

        job_size.times do |index|
          @instances[index] = InstanceSpec.new(self, index)
          @resource_pool.reserve_vm
        end

        network_specs = safe_property(job, "networks", :class => Array)
        if network_specs.empty?
          raise "Job #{@name} must specify at least one network"
        end

        network_specs.each do |network_spec|
          network_name = safe_property(network_spec, "name", :class => String)
          network = @deployment.network(network_name)
          raise "Job '#{@name}' references an unknown network: '#{network_name}'" if network.nil?

          static_ips = nil
          if network_spec["static_ips"]
            static_ips = []
            each_ip(safe_property(network_spec, "static_ips")) { |ip| static_ips << ip }
            if static_ips.size != @instances.size
              raise ArgumentError, "Job #{@name} has #{@instances.size} but was allocated #{static_ips.size}."
            end
          end

          default_network = safe_property(network_spec, "default", :class => Array, :optional => true)
          if default_network
            default_network.each do |property|
              if !NetworkSpec::VALID_DEFAULTS.include?(property)
                raise "Job #{@name} specified an invalid default property: #{property}"
              elsif @default_network[property].nil?
                @default_network[property] = network_name
              else
                raise "Job #{@name} must specify only one default network for: #{property}"
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
          @default_network.each_key { |key| missing_default_properties.delete(key) }
          unless missing_default_properties.empty?
            raise "Job #{@name} must specify a default network for " +
                      "'#{missing_default_properties.sort.join(", ")}' " +
                      "since it has more than one network configured"
          end
        else
          # Set the default network to the one and only available network (if not specified already)
          network = safe_property(network_specs.first, "name", :class => String)
          NetworkSpec::VALID_DEFAULTS.each { |property| @default_network[property] ||= network }
        end
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
        !!@halt
      end

      def record_update_error(error, options = {})
        @error_mutex.synchronize do
          @halt = true
          @halt_exception = error
        end
      end

      def spec
        result = {
            "name" => @name,
            "template" => @template.name,
            "version" => @template.version,
            "sha1" => @template.sha1,
            "blobstore_id" => @template.blobstore_id,
        }

        if @template.logs
          result["logs"] = @template.logs
        end

        result
      end
    end
  end
end