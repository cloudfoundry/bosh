require 'bosh/director/deployment_plan/deployment_spec_parser'
require 'bosh/director/deployment_plan/cloud_manifest_parser'
require 'bosh/director/deployment_plan/disk_pool'
require 'forwardable'

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

      # Hash of resolved links spec provided by deployment
      # in format job_name > template_name > link_name > link_type
      # used by LinksResolver
      attr_accessor :link_spec

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

      attr_writer :cloud_planner

      def initialize(attrs, manifest_text, cloud_config, deployment_model, options = {})
        @cloud_config = cloud_config

        @name = attrs.fetch(:name)
        @properties = attrs.fetch(:properties)
        @releases = {}

        @manifest_text = manifest_text
        @cloud_config = cloud_config
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

        @link_spec = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
      end

      def_delegators :@cloud_planner,
        :networks,
        :network,
        :default_network,
        :availability_zone,
        :availability_zones,
        :resource_pools,
        :resource_pool,
        :disk_pools,
        :disk_pool,
        :compilation

      def canonical_name
        canonical(@name)
      end

      # Returns a list of Instances in the deployment (according to DB)
      # @return [Array<Models::Instance>]
      def instance_models
        @model.instances
      end

      # Returns a list of Instances in the deployment (according to DB)
      # @return [Array<Models::Vm>]
      def vm_models
        @model.vms
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
      def mark_vm_for_deletion(vm)
        @unneeded_vms << vm
      end

      def instances_with_missing_vms
        jobs_starting_on_deploy.collect_concat do |job|
          job.instances_with_missing_vms
        end
      end

      # Adds instance to deletion queue
      # @param [Bosh::Director::DeploymentPlan::ExistingInstance]
      def mark_instance_for_deletion(instance)
        if @jobs_name_index.has_key?(instance.job_name)
          @jobs_name_index[instance.job_name].unneeded_instances << instance
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
        model.link_spec = @link_spec
        model.save
      end

      def update_stemcell_references!
        current_stemcell_models = resource_pools.map { |pool| pool.stemcell.model }
        model.stemcells.each do |deployment_stemcell|
          deployment_stemcell.remove_deployment(model) unless current_stemcell_models.include?(deployment_stemcell)
        end
      end

      def using_global_networking?
        !@cloud_config.nil?
      end
    end

    class CloudPlanner
      attr_accessor :compilation

      attr_reader :default_network

      def initialize(options)
        @networks = index_by_name(options.fetch(:networks))
        @default_network = options.fetch(:default_network)
        @resource_pools = index_by_name(options.fetch(:resource_pools))
        @disk_pools = index_by_name(options.fetch(:disk_pools))
        @availability_zones = index_by_name(options.fetch(:availability_zones))
        @compilation = options.fetch(:compilation)
      end

      def model
        nil
      end

      def availability_zone(name)
        @availability_zones[name]
      end

      def availability_zones
        @availability_zones.values
      end

      def resource_pools
        @resource_pools.values
      end

      def resource_pool(name)
        @resource_pools[name]
      end

      def networks
        @networks.values
      end

      def network(name)
        @networks[name]
      end

      def disk_pools
        @disk_pools.values
      end

      def using_global_networking?
        false
      end

      def disk_pool(name)
        @disk_pools[name]
      end

      private

      def index_by_name(collection)
        collection.inject({}) do |index, item|
          index.merge(item.name => item)
        end
      end
    end
  end
end
