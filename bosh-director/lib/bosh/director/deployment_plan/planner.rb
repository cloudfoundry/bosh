require 'bosh/director/deployment_plan/deployment_spec_parser'
require 'bosh/director/deployment_plan/cloud_manifest_parser'
require 'bosh/director/deployment_plan/disk_pool'
require 'forwardable'
require 'common/deep_copy'

module Bosh::Director
  # Encapsulates essential director data structures retrieved
  # from the deployment manifest and the running environment.
  module DeploymentPlan
    class Planner
      include LockHelper
      include DnsHelper
      include ValidationHelper
      extend Forwardable

      # @return [String] Deployment name
      attr_reader :name

      # @return [String] Deployment canonical name (for DNS)
      attr_reader :canonical_name

      # @return [Models::Deployment] Deployment DB model
      attr_reader :model

      attr_accessor :properties

      # @return [Bosh::Director::DeploymentPlan::UpdateConfig]
      #   Default job update configuration
      attr_accessor :update

      # @return [Array<Bosh::Director::DeploymentPlan::Job>]
      #   All jobs in the deployment
      attr_reader :jobs

      # Job instances from the old manifest that are not in the new manifest
      attr_accessor :unneeded_instances

      # VMs from the old manifest that are not in the new manifest
      attr_accessor :unneeded_vms

      attr_accessor :dns_domain

      attr_reader :job_rename

      # @return [Boolean] Indicates whether VMs should be recreated
      attr_reader :recreate

      # @return [Boolean] Indicates whether VMs should be drained
      attr_reader :skip_drain

      def initialize(attrs, manifest_text, cloud_config, deployment_model, options = {})
        @name = attrs.fetch(:name)
        @properties = attrs.fetch(:properties)
        @releases = {}

        @manifest_text = Bosh::Common::DeepCopy.copy(manifest_text)
        @cloud_config = cloud_config
        @cloud_planner = CloudPlanner.new(cloud_config)
        @model = deployment_model

        @jobs = []
        @jobs_name_index = {}
        @jobs_canonical_name_index = Set.new

        @unneeded_vms = []
        @unneeded_instances = []
        @dns_domain = nil

        @job_rename = safe_property(options, 'job_rename',
          :class => Hash, :default => {})

        @recreate = !!options['recreate']
        @skip_drain = SkipDrain.new(options['skip_drain'])
      end

      def_delegators :@cloud_planner, :add_network, :networks, :network,
        :add_resource_pool, :resource_pools, :resource_pool,
        :add_disk_pool, :disk_pools, :disk_pool,
        :compilation, :compilation=

      def canonical_name
        canonical(@name)
      end

      # Returns a list of VMs in the deployment (according to DB)
      # @return [Array<Models::Vm>]
      def vms
        @model.vms
      end

      def skip_drain_for_job?(name)
        @skip_drain.nil? ? false : @skip_drain.for_job(name)
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

      def reset_jobs
        @jobs = []
      end

      def jobs_starting_on_deploy
        @jobs.select(&:starts_on_deploy?)
      end

      def rename_in_progress?
        @job_rename['old_name'] && @job_rename['new_name']
      end

      def persist_updates!
        #prior updates may have had release versions that we no longer use.
        #remove the references to these stale releases.
        stale_release_versions = (model.release_versions - releases.map(&:model))
        stale_release_names = stale_release_versions.map {|version_model| version_model.release.name}.uniq
        with_release_locks(stale_release_names) do
          stale_release_versions.each do |release_version|
            model.remove_release_version(release_version)
          end
        end

        model.manifest = Psych.dump(@manifest_text)
        model.cloud_config = @cloud_config
        model.save
      end

      def update_stemcell_references!
        current_stemcell_models = resource_pools.map { |pool| pool.stemcell.model }
        model.stemcells.each do |deployment_stemcell|
          deployment_stemcell.remove_deployment(model) unless current_stemcell_models.include?(deployment_stemcell)
        end
      end
    end

    class CloudPlanner
      # @return [Bosh::Director::DeploymentPlan::CompilationConfig]
      #   Resource pool and other configuration for compilation workers
      attr_accessor :compilation

      def initialize(cloud_config)
        @cloud_config = cloud_config
        @networks_canonical_name_index = Set.new

        @networks = {}
        @resource_pools = {}
        @disk_pools = {}
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

      # Adds a disk pool by name
      # @param [Bosh::Director::DeploymentPlan::DiskPool] disk_pool
      def add_disk_pool(disk_pool)
        if @disk_pools[disk_pool.name]
          raise DeploymentDuplicateDiskPoolName,
            "Duplicate disk pool name `#{disk_pool.name}'"
        end
        @disk_pools[disk_pool.name] = disk_pool
      end

      def disk_pools
        @disk_pools.values
      end

      def disk_pool(name)
        @disk_pools[name]
      end
    end
  end
end
