module Bosh::Director

  class DeploymentPlan
    include ValidationHelper

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

    class StemcellSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :resource_pool
      attr_accessor :version
      attr_accessor :network
      attr_accessor :stemcell

      def initialize(resource_pool, stemcell_spec)
        @resource_pool = resource_pool
        @name = safe_property(stemcell_spec, "name", :class => String)
        @version = safe_property(stemcell_spec, "version", :class => String)
        @network = resource_pool.deployment.network(safe_property(stemcell_spec, "network", :class => String))
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

    class ResourcePoolSpec
      include ValidationHelper

      attr_accessor :name
      attr_accessor :deployment
      attr_accessor :stemcell
      attr_accessor :cloud_properties
      attr_accessor :size
      attr_accessor :idle_vms

      def initialize(deployment, resource_pool_spec)
        @deployment = deployment
        @name = safe_property(resource_pool_spec, "name", :class => String)
        @size = safe_property(resource_pool_spec, "size", :class => Integer)
        @cloud_properties = safe_property(resource_pool_spec, "cloud_properties", :class => Hash)
        @stemcell = StemcellSpec.new(self, safe_property(resource_pool_spec, "stemcell", :class => Hash))
        @idle_vms = []
        @allocated_vms = 0
        @reserved_vms = 0
      end

      def add_idle_vm
        idle_vm = IdleVm.new(self)
        @idle_vms << idle_vm
        idle_vm
      end

      def add_allocated_vm
        @allocated_vms += 1
      end

      def reserve_vm
        @reserved_vms += 1
        raise "resource pool too small" if @reserved_vms > @size
      end

      def unallocated_vms
        @size - (@allocated_vms + @idle_vms.size)
      end

      def allocate_vm
        add_allocated_vm
        @idle_vms.shift
      end

      def spec
        {
          "name" => @name,
          "cloud_properties" => @cloud_properties,
          "stemcell" => @stemcell.spec
        }
      end

    end

    class IdleVm

      attr_accessor :resource_pool
      attr_accessor :vm
      attr_accessor :current_state
      attr_accessor :ip

      def initialize(resource_pool)
        @resource_pool = resource_pool
      end

      def network_settings
        network_settings = {}
        network = @resource_pool.stemcell.network
        network_settings[network.name] = network.network_settings(@ip)
        network_settings
      end

      def networks_changed?
        network_settings != @current_state["networks"]
      end

      def resource_pool_changed?
        resource_pool.spec != @current_state["resource_pool"]
      end

      def changed?
        resource_pool_changed? || networks_changed?
      end

    end

    class NetworkSpec
      include IpUtil
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :name

      def initialize(deployment, network_spec)
        @deployment = deployment
        @name = safe_property(network_spec, "name", :class => String)
        @subnets = []
        safe_property(network_spec, "subnets", :class => Array).each do |subnet_spec|
          new_subnet = NetworkSubnetSpec.new(self, subnet_spec)
          @subnets.each do |subnet|
            raise "overlapping subnets" if subnet.overlaps?(new_subnet)
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
        raise "not enough dynamic IPs" unless ip
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

      def network_settings(ip)
        config = nil
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            config = {
              "ip" => ip.ip,
              "netmask" => subnet.netmask,
              "gateway" => subnet.gateway.ip,
              "dns" => subnet.dns,
              "cloud_properties" => subnet.cloud_properties
            }
            break
          end
        end
        config
      end

      def release_dynamic_ip(ip)
        ip = ip_to_netaddr(ip)
        @subnets.each do |subnet|
          if subnet.range.contains?(ip)
            subnet.release_dynamic_ip(ip)
            break
          end
        end
      end

    end

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

        @gateway = NetAddr::CIDR.create(safe_property(subnet_spec, "gateway", :class => String))
        raise ArgumentError, "gateway must be a single ip" unless @gateway.size == 1
        raise ArgumentError, "gateway must be inside the range" unless @range.contains?(@gateway)

        @dns = []
        safe_property(subnet_spec, "dns", :class => Array).each do |dns|
          dns = NetAddr::CIDR.create(dns)
          raise ArgumentError, "dns entry must be a single ip" unless dns.size == 1
          @dns << dns.ip
        end

        @cloud_properties = safe_property(subnet_spec, "cloud_properties", :class => Hash)

        @available_dynamic_ips = Set.new
        @available_static_ips = Set.new

        first_ip = @range.first(:Objectify => true)
        last_ip = @range.last(:Objectify => true)
        (first_ip.to_i .. last_ip.to_i).each { |ip| @available_dynamic_ips << ip }

        @available_dynamic_ips.delete(@gateway.to_i)
        @available_dynamic_ips.delete(@range.network(:Objectify => true).to_i)
        @available_dynamic_ips.delete(@range.broadcast(:Objectify => true).to_i)

        each_ip(safe_property(subnet_spec, "reserved", :class => Array, :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "reserved IP must be an available (not gateway, etc..) inside the range"
          end
        end

        each_ip(safe_property(subnet_spec, "static", :class => Array, :optional => true)) do |ip|
          unless @available_dynamic_ips.delete?(ip)
            raise ArgumentError, "static IP must be an available (not reserved) inside the range"
          end
          @available_static_ips.add(ip)
        end

      end

      def overlaps?(subnet)
        @range == subnet.range || @range.contains?(subnet.range) || subnet.range.contains?(@range)
      end

      def reserve_ip(ip)
        reservation = nil
        if @available_static_ips.delete?(ip)
          reservation = :static
        elsif @available_dynamic_ips.delete?(ip)
          reservation = :dynamic
        end
        reservation
      end

      def allocate_dynamic_ip
        ip = @available_dynamic_ips.first
        if ip
          @available_dynamic_ips.delete(ip)
        end
        ip
      end

      def release_dynamic_ip(ip)
        raise "Invalid dynamic ip" unless @range.contains?(ip)
        # TODO: would be nice to check if it was really a dynamic ip and not reserved/static/etc
        @available_dynamic_ips.add(ip.to_i)
      end

    end

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

    class JobSpec
      include IpUtil
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :name
      attr_accessor :persistent_disk
      attr_accessor :resource_pool
      attr_accessor :template
      attr_accessor :properties
      attr_accessor :packages
      attr_accessor :update
      attr_accessor :update_errors
      attr_accessor :unneeded_instances

      def initialize(deployment, job_spec)
        @deployment = deployment
        @name = safe_property(job_spec, "name", :class => String)
        @template = deployment.template(safe_property(job_spec, "template", :class => String))
        @persistent_disk = safe_property(job_spec, "persistent_disk", :class => Integer, :optional => true) || 0
        @instances = []
        @packages = {}
        properties = safe_property(job_spec, "properties", :class => Hash, :optional => true)
        if properties.nil?
          @properties = deployment.properties
        else
          @properties = deployment.properties._deep_copy
          @properties.recursive_merge!(properties)
        end
        @resource_pool = deployment.resource_pool(safe_property(job_spec, "resource_pool", :class => String))
        if @resource_pool.nil?
          raise ArgumentError, "Job #{@name} references an unknown resource pool: #{job_spec["resource_pool"]}"
        end
        @update = UpdateConfig.new(safe_property(job_spec, "update", :class => Hash, :optional => true), deployment.update)
        @rollback = false
        @update_errors = 0
        @unneeded_instances = []

        safe_property(job_spec, "instances", :class => Integer).times do |index|
          @instances[index] = InstanceSpec.new(self, index)
          @resource_pool.reserve_vm
        end

        safe_property(job_spec, "networks", :class => Array).each do |network_spec|
          network_name = safe_property(network_spec, "name", :class => String)
          static_ips = nil
          if network_spec["static_ips"]
            static_ips = []
            each_ip(safe_property(network_spec, "static_ips", :class => Array)) { |ip| static_ips << ip }
            if static_ips.size != @instances.size
              raise ArgumentError, "Job #{@name} has #{@instances.size} but was allocated #{static_ips.size}."
            end
          end

          @instances.each_with_index do |instance, index|
            network = instance.add_network(network_name)
            if static_ips
              network.ip = static_ips[index]
            end
          end
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

      def should_rollback?
        @rollback
      end

      def record_update_error(error, options = {})
        @update_errors += 1
        if options[:canary] || (@update.max_errors > 0 && @update.max_errors < @update_errors)
          @rollback = true
        end
      end

      def spec
        {
          "name" => @name,
          "version" => @template.version,
          "sha1" => @template.sha1,
          "blobstore_id" => @template.blobstore_id
        }
      end

    end

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

    class InstanceSpec

      attr_accessor :job
      attr_accessor :index
      attr_accessor :instance
      attr_accessor :configuration_hash
      attr_accessor :current_state

      def initialize(job, index)
        @job = job
        @index = index
        @networks = {}
      end

      def add_network(name)
        raise "network #{name} already exists" if @networks.has_key?(name)
        @networks[name] = InstanceNetwork.new(self, name)
      end

      def network(name)
        network = @networks[name]
        raise "network #{name} not found" if network.nil?
        network
      end

      def networks
        @networks.values
      end

      def network_settings
        network_settings = {}
        @networks.each_value do |instance_network|
          network = @job.deployment.network(instance_network.name)
          network_settings[instance_network.name] = network.network_settings(instance_network.ip)
        end
        network_settings
      end

      def networks_changed?
        network_settings != @current_state["networks"]
      end

      def resource_pool_changed?
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
        @job.persistent_disk != @current_state["persistent_disk"]
      end

      def changed?
        resource_pool_changed? || networks_changed? || packages_changed? || persistent_disk_changed? ||
                configuration_changed? || job_changed?
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

    class UpdateConfig
      include ValidationHelper

      attr_accessor :canaries
      attr_accessor :canary_watch_time
      attr_accessor :max_in_flight
      attr_accessor :update_watch_time
      attr_accessor :max_errors

      def initialize(update_config, default_update_config = nil)
        optional = !default_update_config.nil?
        @canaries = safe_property(update_config, "canaries", :class => Integer, :optional => optional)
        @canary_watch_time = safe_property(update_config, "canary_watch_time", :class => Integer, :optional => optional)
        @max_in_flight = safe_property(update_config, "max_in_flight", :class => Integer, :optional => optional,
                                       :min => 1, :max => 32)
        @update_watch_time = safe_property(update_config, "update_watch_time", :class => Integer, :optional => optional)
        @max_errors = safe_property(update_config, "max_errors", :class => Integer, :optional => optional)

        if optional
          @canaries ||= default_update_config.canaries
          @canary_watch_time ||= default_update_config.canary_watch_time
          @max_in_flight ||= default_update_config.max_in_flight
          @update_watch_time ||= default_update_config.update_watch_time
          @max_errors ||= default_update_config.max_errors
        end
      end

    end

    class CompilationConfig
      include ValidationHelper

      attr_accessor :deployment
      attr_accessor :workers
      attr_accessor :network
      attr_accessor :cloud_properties

      def initialize(deployment, compilation_config)
        @deployment = deployment
        @workers = safe_property(compilation_config, "workers", :class => Integer)
        @network = deployment.network(safe_property(compilation_config, "network", :class => String))
        @cloud_properties = safe_property(compilation_config, "cloud_properties", :class => Hash)
      end
    end

    attr_accessor :name
    attr_accessor :release
    attr_accessor :deployment
    attr_accessor :properties
    attr_accessor :compilation
    attr_accessor :update
    attr_accessor :unneeded_instances
    attr_accessor :unneeded_vms

    def initialize(manifest)
      @name = safe_property(manifest, "name", :class => String)
      @release = ReleaseSpec.new(self, safe_property(manifest, "release", :class => Hash))
      @properties = safe_property(manifest, "properties", :class => Hash, :optional => true) || {}
      @properties.extend(DeepCopy)

      @networks = {}
      networks = safe_property(manifest, "networks", :class => Array)
      networks.each do |network_spec|
        network = NetworkSpec.new(self, network_spec)
        @networks[network.name] = network
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
      jobs = safe_property(manifest, "jobs", :class => Array, :optional => true)
      if jobs
        jobs.each do |job_spec|
          job = JobSpec.new(self, job_spec)
          @jobs << job
          @jobs_name_index[job.name] = job
        end
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
      template = @templates[name]
      if template.nil?
        @templates[name] = template = TemplateSpec.new(@deployment, name)
      end
      template
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

  end
end
