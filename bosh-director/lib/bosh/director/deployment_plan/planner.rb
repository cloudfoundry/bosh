require 'bosh/director/deployment_plan/deployment_spec_parser'

module Bosh::Director
  # Encapsulates essential director data structures retrieved
  # from the deployment manifest and the running environment.
  module DeploymentPlan
    class Planner
      include DnsHelper
      include ValidationHelper

      # @return [String] Deployment name
      attr_reader :name

      # @return [String] Deployment canonical name (for DNS)
      attr_reader :canonical_name

      # @return [Models::Deployment] Deployment DB model
      attr_reader :model

      attr_accessor :properties

      # @return [Bosh::Director::DeploymentPlan::CompilationConfig]
      #   Resource pool and other configuration for compilation workers
      attr_accessor :compilation

      # @return [Bosh::Director::DeploymentPlan::UpdateConfig]
      #   Default job update configuration
      attr_accessor :update

      # @return [Array<Bosh::Director::DeploymentPlan::Job>]
      #   All jobs in the deployment
      attr_reader :jobs

      attr_accessor :unneeded_instances
      attr_accessor :unneeded_vms
      attr_accessor :dns_domain

      attr_reader :job_rename

      # @return [Boolean] Indicates whether VMs should be recreated
      attr_reader :recreate

      # @param [Hash] manifest Raw deployment manifest
      # @param [Bosh::Director::EventLog::Log]
      #   event_log Event log for recording deprecations
      # @param [Hash] options Additional options for deployment
      #   (e.g. job_states, job_rename)
      # @return [Bosh::Director::DeploymentPlan::Planner]
      def self.parse(manifest, event_log, options)
        parser = DeploymentSpecParser.new(event_log)
        parser.parse(manifest, options)
      end

      def initialize(name, options = {})
        raise ArgumentError, 'name must not be nil' unless name
        @name = name
        @model = nil

        @properties = {}
        @releases = {}
        @networks = {}
        @networks_canonical_name_index = Set.new

        @resource_pools = {}

        @jobs = []
        @jobs_name_index = {}
        @jobs_canonical_name_index = Set.new

        @unneeded_vms = []
        @unneeded_instances = []
        @dns_domain = nil

        @job_rename = safe_property(options, 'job_rename',
          :class => Hash, :default => {})

        @recreate = !!options['recreate']
      end

      def canonical_name
        canonical(@name)
      end

      # Looks up deployment model in DB or creates one if needed
      # @return [void]
      def bind_model
        attrs = {:name => @name}

        Models::Deployment.db.transaction do
          deployment = Models::Deployment.find(attrs)

          # Canonical uniqueness is not enforced in the DB
          if deployment.nil?
            Models::Deployment.each do |other|
              if canonical(other.name) == canonical_name
                raise DeploymentCanonicalNameTaken,
                      "Invalid deployment name `#{@name}', " +
                        'canonical name already taken'
              end
            end
            deployment = Models::Deployment.create(attrs)
          end

          @model = deployment
        end
      end

      # Returns a list of VMs in the deployment (according to DB)
      # @return [Array<Models::Vm>]
      def vms
        if @model.nil?
          raise DirectorError, "Can't get VMs list, deployment model is unbound"
        end
        @model.vms
      end

      # Adds a network by name
      # @param [Bosh::Director::DeploymentPlan::Network] network
      def add_network(network)
        if @networks_canonical_name_index.include?(network.canonical_name)
          raise DeploymentCanonicalNetworkNameTaken,
            "Invalid network name `#{network.name}', " +
              'canonical name already taken'
        end

        @networks[network.name] = network
        @networks_canonical_name_index << network.canonical_name
      end

      # Returns all networks in a deployment plan
      # @return [Array<Bosh::Director::DeploymentPlan::Network>]
      def networks
        @networks.values
      end

      # Returns a named network
      # @param [String] name
      # @return [Bosh::Director::DeploymentPlan::Network]
      def network(name)
        @networks[name]
      end

      # Adds a resource pool by name
      # @param [Bosh::Director::DeploymentPlan::ResourcePool] resource_pool
      def add_resource_pool(resource_pool)
        if @resource_pools[resource_pool.name]
          raise DeploymentDuplicateResourcePoolName,
            "Duplicate resource pool name `#{resource_pool.name}'"
        end
        @resource_pools[resource_pool.name] = resource_pool
      end

      # Returns all resource pools in a deployment plan
      # @return [Array<Bosh::Director::DeploymentPlan::ResourcePool>]
      def resource_pools
        @resource_pools.values
      end

      # Returns a named resource pool spec
      # @param [String] name Resource pool name
      # @return [Bosh::Director::DeploymentPlan::ResourcePool]
      def resource_pool(name)
        @resource_pools[name]
      end

      # Adds a release by name
      # @param [Bosh::Director::DeploymentPlan::ReleaseVersion] release
      def add_release(release)
        if @releases.has_key?(release.name)
          raise DeploymentDuplicateReleaseName,
            "Duplicate release name `#{release.name}'"
        end
        @releases[release.name] = release
      end

      # Returns all releases in a deployment plan
      # @return [Array<Bosh::Director::DeploymentPlan::ReleaseVersion>]
      def releases
        @releases.values
      end

      # Returns a named release
      # @return [Bosh::Director::DeploymentPlan::ReleaseVersion]
      def release(name)
        @releases[name]
      end

      # Adds a VM to deletion queue
      # @param [Bosh::Director::Models::Vm] vm VM DB model
      def delete_vm(vm)
        @unneeded_vms << vm
      end

      # Adds instance to deletion queue
      # @param [Bosh::Director::Models::Instance] instance Instance DB model
      def delete_instance(instance)
        if @jobs_name_index.has_key?(instance.job)
          @jobs_name_index[instance.job].unneeded_instances << instance
        else
          @unneeded_instances << instance
        end
      end

      # Adds a job by name
      # @param [Bosh::Director::DeploymentPlan::Job] job
      def add_job(job)
        if rename_in_progress? && @job_rename['old_name'] == job.name
          raise DeploymentRenamedJobNameStillUsed,
            "Renamed job `#{job.name}' is still referenced in " +
              'deployment manifest'
        end

        if @jobs_canonical_name_index.include?(job.canonical_name)
          raise DeploymentCanonicalJobNameTaken,
            "Invalid job name `#{job.name}', canonical name already taken"
        end

        @jobs << job
        @jobs_name_index[job.name] = job
        @jobs_canonical_name_index << job.canonical_name
      end

      # Returns a named job
      # @param [String] name Job name
      # @return [Bosh::Director::DeploymentPlan::Job] Job
      def job(name)
        @jobs_name_index[name]
      end

      def jobs_starting_on_deploy
        @jobs.select(&:starts_on_deploy?)
      end

      def rename_in_progress?
        @job_rename['old_name'] && @job_rename['new_name']
      end
    end
  end
end
