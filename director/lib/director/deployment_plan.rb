# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director

  # TODO: CLEANUP, refactor into multiple files and cleanup exceptions
  class DeploymentPlan
    include DnsHelper
    include ValidationHelper

    attr_accessor :name
    attr_accessor :canonical_name
    attr_accessor :release
    attr_accessor :deployment
    attr_accessor :properties
    attr_accessor :compilation
    attr_accessor :update
    attr_accessor :unneeded_instances
    attr_accessor :unneeded_vms
    attr_accessor :dns_domain
    attr_reader   :recreate

    def initialize(manifest, options = {})
      @name = safe_property(manifest, "name", :class => String)
      @canonical_name = canonical(@name)

      @properties = safe_property(manifest, "properties", :class => Hash, :default => { })
      @properties.extend(DeepCopy)

      @recreate   = !!options["recreate"]
      @job_states = safe_property(options, "job_states", :class => Hash, :default => { })

      @release = ReleaseSpec.new(self, safe_property(manifest, "release", :class => Hash))

      @networks = {}
      @networks_canonical_name_index = Set.new
      networks = safe_property(manifest, "networks", :class => Array)
      networks.each do |network_spec|
        network = NetworkSpec.new(self, network_spec)
        if @networks_canonical_name_index.include?(network.canonical_name)
          raise "Invalid network name: '#{network.name}', canonical name already taken."
        end
        @networks[network.name] = network
        @networks_canonical_name_index << network.canonical_name
      end

      @compilation = CompilationConfig.new(self, safe_property(manifest, "compilation", :class => Hash))
      @update = UpdateConfig.new(safe_property(manifest, "update", :class => Hash))

      @resource_pools = {}
      resource_pools = safe_property(manifest, "resource_pools", :class => Array)
      resource_pools.each do |resource_pool_spec|
        resource_pool = ResourcePoolSpec.new(self, resource_pool_spec)
        @resource_pools[resource_pool.name] = resource_pool
      end

      @templates = {}
      @jobs = []
      @jobs_name_index = {}
      @jobs_canonical_name_index = Set.new

      jobs = safe_property(manifest, "jobs", :class => Array, :default => [ ])

      jobs.each do |job|
        state_overrides = @job_states[job["name"]]

        if state_overrides
          job.recursive_merge!(state_overrides)
        end

        job = JobSpec.new(self, job)
        if @jobs_canonical_name_index.include?(job.canonical_name)
          raise "Invalid job name: '#{job.name}', canonical name already taken."
        end

        @jobs << job
        @jobs_name_index[job.name] = job
        @jobs_canonical_name_index << job.canonical_name
      end

      @unneeded_vms = []
      @unneeded_instances = []
    end

    def jobs
      @jobs
    end

    def job(name)
      @jobs_name_index[name]
    end

    def template(name)
      @templates[name] ||= TemplateSpec.new(@deployment, name)
    end

    def templates
      @templates.values
    end

    def networks
      @networks.values
    end

    def network(name)
      @networks[name]
    end

    def resource_pools
      @resource_pools.values
    end

    def resource_pool(name)
      @resource_pools[name]
    end

    def delete_vm(vm)
      @unneeded_vms << vm
    end

    def delete_instance(instance)
      if @jobs_name_index.has_key?(instance.job)
        @jobs_name_index[instance.job].unneeded_instances << instance
      else
        @unneeded_instances << instance
      end
    end


    # DeploymentPlan::ReleaseSpec
    class ReleaseSpec
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :version
      attr_accessor :release
      attr_accessor :release_version

      def initialize(deployment, release_spec)
        @deployment = deployment
        @name = safe_property(release_spec, "name", :class => String)
        @version = safe_property(release_spec, "version", :class => String)
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end
    end


    # DeploymentPlan::StemcellSpec
    class StemcellSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :resource_pool
      attr_accessor :version
      attr_accessor :stemcell

      def initialize(resource_pool, stemcell_spec)
        @resource_pool = resource_pool
        @name = safe_property(stemcell_spec, "name", :class => String)
        @version = safe_property(stemcell_spec, "version", :class => String)
      end

      def spec
        {
          "name" => @name,
          "version" => @version
        }
      end

      def method_missing(method_name, *args)
        @stemcell.send(method_name, *args)
      end
    end


    # DeploymentPlan::ResourcePoolSpec
    class ResourcePoolSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :deployment
      attr_accessor :stemcell
      attr_accessor :network
      attr_accessor :cloud_properties
      attr_accessor :env
      attr_accessor :env_hash
      attr_accessor :size
      attr_accessor :idle_vms
      attr_accessor :allocated_vms
      attr_accessor :active_vms

      def initialize(deployment, resource_pool_spec)
        @deployment = deployment
        @name = safe_property(resource_pool_spec, "name", :class => String)
        @size = safe_property(resource_pool_spec, "size", :class => Integer)
        @cloud_properties = safe_property(resource_pool_spec, "cloud_properties", :class => Hash)
        @stemcell = StemcellSpec.new(self, safe_property(resource_pool_spec, "stemcell", :class => Hash))

        network_name = safe_property(resource_pool_spec, "network", :class => String)
        @network = @deployment.network(network_name)
        raise "Resource pool '#{@name}' references an unknown network: '#{network_name}'" if @network.nil?

        @env = safe_property(resource_pool_spec, "env", :class => Hash, :optional => true) || {}
        @env_hash = Digest::SHA1.hexdigest(Yajl::Encoder.encode(@env.sort))

        @idle_vms = []
        @allocated_vms = []
        @active_vms = 0
        @reserved_vms = 0
      end

      def add_idle_vm
        idle_vm = IdleVm.new(self)
        @idle_vms << idle_vm
        idle_vm
      end

      def mark_active_vm
        @active_vms += 1
      end

      def reserve_vm
        @reserved_vms += 1
        raise "Resource pool '#{@name}' is not big enough to run all the requested jobs" if @reserved_vms > @size
      end

      def allocate_vm
        allocated_vm = @idle_vms.pop
        @allocated_vms << allocated_vm
        allocated_vm
      end

      def spec
        {
          "name" => @name,
          "cloud_properties" => @cloud_properties,
          "stemcell" => @stemcell.spec
        }
      end
    end


    # DeploymentPlan::IdleVm
    class IdleVm

      attr_accessor :resource_pool
      attr_accessor :vm
      attr_accessor :current_state
      attr_accessor :ip
      attr_accessor :bound_instance

      def initialize(resource_pool)
        @resource_pool = resource_pool
      end

      def network_settings
        if @bound_instance
          # use the network settings of the bound instance
          @bound_instance.network_settings
        else
          # if there is no instance, then use resource pool network
          network_settings = {}
          network = @resource_pool.network
          network_settings[network.name] = network.network_settings(
              @ip, NetworkSpec::VALID_DEFAULT_NETWORK_PROPERTIES_ARRAY)
          network_settings
        end
      end

      def networks_changed?
        network_settings != @current_state["networks"]
      end

      def resource_pool_changed?
        resource_pool.spec != @current_state["resource_pool"] || resource_pool.deployment.recreate
      end

      def changed?
        resource_pool_changed? || networks_changed?
      end
    end


    # DeploymentPlan::NetworkSpec
    class NetworkSpec
      include IpUtil
      include DnsHelper
      include ValidationHelper

      VALID_DEFAULT_NETWORK_PROPERTIES = Set.new(["dns", "gateway"])
      VALID_DEFAULT_NETWORK_PROPERTIES_ARRAY = VALID_DEFAULT_NETWORK_PROPERTIES.to_a.sort

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :canonical_name

      def initialize(deployment, network_spec)
        @deployment = deployment
        @name = safe_property(network_spec, "name", :class => String)
        @canonical_name = canonical(@name)
        @subnets = []
        safe_property(network_spec, "subnets", :class => Array).each do |subnet_spec|
          new_subnet = NetworkSubnetSpec.new(self, subnet_spec)
          @subnets.each do |subnet|
            raise "Overlapping subnets" if subnet.overlaps?(new_subnet)
          end
          @subnets << new_subnet
        end
      end

      def allocate_dynamic_ip
        ip = nil
        @subnets.each do |subnet|
          ip = subnet.allocate_dynamic_ip
          break if ip
        end
        unless ip
          raise Bosh::Director::NotEnoughCapacity, "not enough dynamic IPs"
        end
        ip
      end

      def reserve_ip(ip)
        ip = ip_to_i(ip)

        reserved = nil
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            reserved = subnet.reserve_ip(ip)
            break
          end
        end
        reserved
      end

      def network_settings(ip, default_properties)
        config = nil
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            config = {
              "ip" => ip.ip,
              "netmask" => subnet.netmask,
              "cloud_properties" => subnet.cloud_properties
            }

            if default_properties
              config["default"] = default_properties.sort
            end

            config["dns"] = subnet.dns if subnet.dns
            config["gateway"] = subnet.gateway.ip if subnet.gateway
            break
          end
        end
        config
      end

      def release_ip(ip)
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            subnet.release_ip(ip)
            break
          end
        end
      end
    end

    # DeploymentPlan::NetworkSubnetSpec
    class NetworkSubnetSpec
      include IpUtil
      include ValidationHelper

      attr_accessor :network
      attr_accessor :range
      attr_accessor :gateway
      attr_accessor :dns
      attr_accessor :cloud_properties
      attr_accessor :netmask

      def initialize(network, subnet_spec)
        @network = network
        @range = NetAddr::CIDR.create(safe_property(subnet_spec, "range", :class => String))
        raise ArgumentError, "invalid range" unless @range.size > 1

        @netmask = @range.wildcard_mask

        gateway_property = safe_property(subnet_spec, "gateway", :class => String, :optional => true)
        if gateway_property
          @gateway = NetAddr::CIDR.create(gateway_property)
          raise ArgumentError, "gateway must be a single ip" unless @gateway.size == 1
          raise ArgumentError, "gateway must be inside the range" unless @range.contains?(@gateway)
        end

        dns_property = safe_property(subnet_spec, "dns", :class => Array, :optional => true)
        if dns_property
          @dns = []
          dns_property.each do |dns|
            dns = NetAddr::CIDR.create(dns)
            raise ArgumentError, "dns entry must be a single ip" unless dns.size == 1
            @dns << dns.ip
          end
        end

        @cloud_properties = safe_property(subnet_spec, "cloud_properties", :class => Hash)

        @available_dynamic_ips = Set.new
        @available_static_ips = Set.new

        first_ip = @range.first(:Objectify => true)
        last_ip = @range.last(:Objectify => true)

        (first_ip.to_i .. last_ip.to_i).each { |ip| @available_dynamic_ips << ip }

        @available_dynamic_ips.delete(@gateway.to_i) if @gateway
        @available_dynamic_ips.delete(@range.network(:Objectify => true).to_i)
        @available_dynamic_ips.delete(@range.broadcast(:Objectify => true).to_i)

        each_ip(safe_property(subnet_spec, "reserved", :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "reserved IP must be an available (not gateway, etc..) inside the range"
          end
        end

        each_ip(safe_property(subnet_spec, "static", :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "static IP must be an available (not reserved) inside the range"
          end
          @available_static_ips.add(ip)
        end

        # Keeping track of initial pools to understand
        # where to release no longer needed IPs
        @dynamic_ip_pool = @available_dynamic_ips.dup
        @static_ip_pool = @available_static_ips.dup
      end

      def overlaps?(subnet)
        @range == subnet.range || @range.contains?(subnet.range) || subnet.range.contains?(@range)
      end

      def reserve_ip(ip)
        if @available_static_ips.delete?(ip.to_i)
          :static
        elsif @available_dynamic_ips.delete?(ip.to_i)
          :dynamic
        else
          nil
        end
      end

      def release_ip(ip)
        ip = ip.to_i

        if @dynamic_ip_pool.include?(ip)
          @available_dynamic_ips.add(ip)
        elsif @static_ip_pool.include?(ip)
          @available_static_ips.add(ip)
        else
          raise "Invalid IP to release: neither in dynamic nor in static pool"
        end
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
      end
    end

    # DeploymentPlan::TemplateSpec
    class TemplateSpec
      attr_accessor :deployment
      attr_accessor :template
      attr_accessor :name
      attr_accessor :packages

      def initialize(deployment, name)
        @deployment = deployment
        @name = name
      end

      def method_missing(method_name, *args)
        @template.send(method_name, *args)
      end
    end


    # DeploymentPlan::JobSpec
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
              if !NetworkSpec::VALID_DEFAULT_NETWORK_PROPERTIES.include?(property)
                raise "Job #{@name} specified an invalid default property: #{property}"
              elsif @default_network[property].nil?
                @default_network[property] = network_name
              else
                raise "Job #{@name} must specify only one default network for: #{property}"
              end
            end
          end

          @instances.each_with_index do |instance, index|
            network = instance.add_network(network_name)
            if static_ips
              network.ip = static_ips[index]
            end
          end
        end

        if network_specs.size > 1
          missing_default_properties = NetworkSpec::VALID_DEFAULT_NETWORK_PROPERTIES.dup
          @default_network.each_key { |key| missing_default_properties.delete(key) }
          unless missing_default_properties.empty?
            raise "Job #{@name} must specify a default network for " +
                      "'#{missing_default_properties.to_a.sort.join(", ")}' " +
                      "since it has more than one network configured"
          end
        else
          # Set the default network to the one and only available network (if not specified already)
          network = safe_property(network_specs.first, "name", :class => String)
          NetworkSpec::VALID_DEFAULT_NETWORK_PROPERTIES.each { |property| @default_network[property] ||= network }
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


    # DeploymentPlan::PackageSpec
    class PackageSpec
      attr_accessor :package
      attr_accessor :compiled_package

      def initialize(package, compiled_package)
        @package = package
        @compiled_package = compiled_package
      end

      def spec
        {
          "name" => @package.name,
          "version" => "#{@package.version}.#{@compiled_package.build}",
          "sha1" => @compiled_package.sha1,
          "blobstore_id" => @compiled_package.blobstore_id
        }
      end
    end


    # DeploymentPlan::InstanceSpec
    class InstanceSpec
      include DnsHelper

      attr_accessor :job
      attr_accessor :index
      attr_accessor :instance
      attr_accessor :configuration_hash
      attr_accessor :state
      attr_accessor :current_state
      attr_accessor :idle_vm
      attr_accessor :recreate
      attr_accessor :restart

      def initialize(job, index)
        @job = job
        @index = index
        @networks = {}
        @state = job.instance_states[index] || job.state

        # Expanding virtual states
        case @state
        when "recreate"
          @recreate = true
          @state = "started"
        when "restart"
          @restart = true
          @state = "started"
        end
      end

      def add_network(name)
        raise "network #{name} already exists" if @networks.has_key?(name)
        @networks[name] = InstanceNetwork.new(self, name)
      end

      def network(name)
        @networks[name]
      end

      def networks
        @networks.values
      end

      def network_settings
        default_network_properties = {}
        @job.default_network.each { |key, value| (default_network_properties[value] ||= []) << key}

        network_settings = {}
        @networks.each_value do |instance_network|
          network = @job.deployment.network(instance_network.name)
          network_settings[instance_network.name] = network.network_settings(
              instance_network.ip, default_network_properties[instance_network.name])
        end
        network_settings
      end

      def disk_size
        if @instance.nil?
          current_state["persistent_disk"].to_i
        elsif @instance.persistent_disk
          @instance.persistent_disk.size
        else
          0
        end
      end

      def dns_records
        return @dns_records if @dns_records
        @dns_records = {}
        network_settings.each do |network_name, network|
          name = [index, job.canonical_name, canonical(network_name), job.deployment.canonical_name, :bosh].join(".")
          @dns_records[name] = network["ip"]
        end
        @dns_records
      end

      def disk_currently_attached?
        current_state["persistent_disk"].to_i > 0
      end

      def networks_changed?
        network_settings != @current_state["networks"]
      end

      def resource_pool_changed?
        @recreate ||
          @job.deployment.recreate ||
          @job.resource_pool.spec != @current_state["resource_pool"]
      end

      def configuration_changed?
        configuration_hash != @current_state["configuration_hash"]
      end

      def job_changed?
        @job.spec != @current_state["job"]
      end

      def packages_changed?
        @job.package_spec != @current_state["packages"]
      end

      def persistent_disk_changed?
        @job.persistent_disk != disk_size
      end

      def dns_changed?
        if Config.dns_enabled?
          dns_records.any? { |name, ip| Models::Dns::Record.find(:name => name, :type => "A", :content => ip).nil? }
        else
          false
        end
      end

      # Checks if agent view of the instance state
      # is consistent with target instance state.
      # In case the instance current state is 'detached'
      # we should never get to this method call.
      def state_changed?
        @state == "detached" ||
          @state == "started" && @current_state["job_state"] != "running" ||
          @state == "stopped" && @current_state["job_state"] == "running"
      end

      def changed?
        !changes.empty?
      end

      def changes
        changes = Set.new
        unless @state == "detached" && @current_state.nil?
          changes << :restart if @restart
          changes << :resource_pool if resource_pool_changed?
          changes << :network if networks_changed?
          changes << :packages if packages_changed?
          changes << :persistent_disk if persistent_disk_changed?
          changes << :configuration if configuration_changed?
          changes << :job if job_changed?
          changes << :state if state_changed?
          changes << :dns if dns_changed?
        end
        changes
      end

      def spec
        deployment_plan = @job.deployment
        {
          "deployment" => deployment_plan.name,
          "release" => deployment_plan.release.spec,
          "job" => job.spec,
          "index" => index,
          "networks" => network_settings,
          "resource_pool" => job.resource_pool.spec,
          "packages" => job.package_spec,
          "persistent_disk" => job.persistent_disk,
          "configuration_hash" => configuration_hash,
          "properties" => job.properties
        }
      end
    end

    # DeploymentPlan::InstanceNetwork
    class InstanceNetwork
      include IpUtil

      attr_accessor :instance
      attr_accessor :name
      attr_accessor :ip
      attr_accessor :reserved

      def initialize(instance, name)
        @instance = instance
        @name = name
        @ip = nil
        @reserved = false
      end

      def use_reservation(ip, static)
        ip = ip_to_i(ip)
        if @ip
          if @ip == ip && static
            @reserved = true
          end
        elsif !static
          @ip = ip
          @reserved = true
        end
      end
    end


    # DeploymentPlan::UpdateConfig
    class UpdateConfig
      include ValidationHelper

      attr_accessor :canaries
      attr_accessor :max_in_flight

      attr_accessor :min_canary_watch_time
      attr_accessor :max_canary_watch_time

      attr_accessor :min_update_watch_time
      attr_accessor :max_update_watch_time

      def initialize(update_config, default_update_config = nil)
        optional = !default_update_config.nil?

        @canaries = safe_property(update_config, "canaries", :class => Integer, :optional => optional)

        @max_in_flight = safe_property(update_config, "max_in_flight", :class => Integer, :optional => optional,
                                       :min => 1, :max => 32)

        canary_watch_times = safe_property(update_config, "canary_watch_time", :class => String, :optional => optional)
        update_watch_times = safe_property(update_config, "update_watch_time", :class => String, :optional => optional)

        if canary_watch_times
          @min_canary_watch_time, @max_canary_watch_time = parse_watch_times(canary_watch_times)
        end

        if update_watch_times
          @min_update_watch_time, @max_update_watch_time = parse_watch_times(update_watch_times)
        end

        if optional
          @canaries ||= default_update_config.canaries

          @min_canary_watch_time ||= default_update_config.min_canary_watch_time
          @max_canary_watch_time ||= default_update_config.max_canary_watch_time

          @min_update_watch_time ||= default_update_config.min_update_watch_time
          @max_update_watch_time ||= default_update_config.max_update_watch_time

          @max_in_flight ||= default_update_config.max_in_flight
        end
      end

      def parse_watch_times(value)
        value = value.to_s

        if value =~ /^\s*(\d+)\s*\-\s*(\d+)\s*$/
          result = [$1.to_i, $2.to_i]
        elsif value =~ /^\s*(\d+)\s*$/
          result = [$1.to_i, $1.to_i]
        else
          raise ArgumentError, "Watch time should be an integer or a range of two integers"
        end

        if result[0] > result[1]
          raise ArgumentError, "Min watch time cannot be greater than max watch time"
        end

        result
      end
    end


    # DeploymentPlan::CompilationConfig
    class CompilationConfig
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :workers
      attr_accessor :network
      attr_accessor :cloud_properties
      attr_accessor :env

      def initialize(deployment, compilation_config)
        @deployment = deployment
        @workers = safe_property(compilation_config, "workers", :class => Integer)
        network_name = safe_property(compilation_config, "network", :class => String)
        @network = deployment.network(network_name)
        raise "Compilation workers reference an unknown network: '#{network_name}'" if @network.nil?
        @cloud_properties = safe_property(compilation_config, "cloud_properties", :class => Hash)
        @env = safe_property(compilation_config, "env", :class => Hash, :optional => true) || {}
      end
    end

  end
end
