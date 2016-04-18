require 'bosh/director/deployment_plan/deployment_spec_parser'
require 'bosh/director/deployment_plan/cloud_manifest_parser'
require 'bosh/director/deployment_plan/runtime_manifest_parser'
require 'bosh/director/deployment_plan/disk_type'
require 'forwardable'
require 'common/deep_copy'

module Bosh::Director
  # Encapsulates essential director data structures retrieved
  # from the deployment manifest and the running environment.
  module DeploymentPlan
    class Planner
      include LockHelper
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

      # Stemcells in deployment by alias
      attr_reader :stemcells

      # Job instances from the old manifest that are not in the new manifest
      attr_reader :unneeded_instances

      # @return [Boolean] Indicates whether VMs should be recreated
      attr_reader :recreate

      attr_writer :cloud_planner

      # @return [Boolean] Indicates whether VMs should be drained
      attr_reader :skip_drain

      def initialize(attrs, manifest_text, cloud_config, runtime_config, deployment_model, options = {})
        @name = attrs.fetch(:name)
        @properties = attrs.fetch(:properties)
        @releases = {}

        @manifest_text = Bosh::Common::DeepCopy.copy(manifest_text)
        @cloud_config = cloud_config
        @runtime_config = runtime_config
        @model = deployment_model

        @stemcells = {}
        @jobs = []
        @jobs_name_index = {}
        @jobs_canonical_name_index = Set.new

        @unneeded_vms = []
        @unneeded_instances = []

        @recreate = !!options['recreate']

        @link_spec = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
        @skip_drain = SkipDrain.new(options['skip_drain'])

        @logger = Config.logger
      end

      def_delegators :@cloud_planner,
        :networks,
        :network,
        :deleted_network,
        :availability_zone,
        :availability_zones,
        :resource_pools,
        :resource_pool,
        :vm_types,
        :vm_type,
        :vm_extensions,
        :vm_extension,
        :add_resource_pool,
        :disk_types,
        :disk_type,
        :compilation,
        :ip_provider

      def canonical_name
        Canonicalizer.canonicalize(@name)
      end

      def bind_models(skip_links_binding = false)
        stemcell_manager = Api::StemcellManager.new
        dns_manager = DnsManagerProvider.create
        assembler = DeploymentPlan::Assembler.new(
          self,
          stemcell_manager,
          dns_manager,
          Config.cloud,
          @logger
        )

        assembler.bind_models(skip_links_binding)
      end

      def compile_packages
        validate_packages

        cloud = Config.cloud
        vm_deleter = VmDeleter.new(cloud, @logger)
        disk_manager = DiskManager.new(cloud, @logger)
        job_renderer = JobRenderer.create
        arp_flusher = ArpFlusher.new
        vm_creator = Bosh::Director::VmCreator.new(cloud, @logger, vm_deleter, disk_manager, job_renderer, arp_flusher)
        dns_manager = DnsManagerProvider.create
        instance_deleter = Bosh::Director::InstanceDeleter.new(ip_provider, dns_manager, disk_manager)
        compilation_instance_pool = CompilationInstancePool.new(
          InstanceReuser.new,
          vm_creator,
          self,
          @logger,
          instance_deleter,
          compilation.workers)
        package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
          jobs,
          compilation,
          compilation_instance_pool,
          @logger,
          nil
        )
        package_compile_step.perform
      end

      # Returns a list of Instances in the deployment (according to DB)
      # @return [Array<Models::Instance>]
      def instance_models
        @model.instances
      end

      def existing_instances
        instance_models
      end

      def candidate_existing_instances
        desired_job_names = jobs.map(&:name)
        migrating_job_names = jobs.map(&:migrated_from).flatten.map(&:name)

        existing_instances.select do |instance|
          desired_job_names.include?(instance.job) ||
            migrating_job_names.include?(instance.job)
        end
      end

      def skip_drain_for_job?(name)
        @skip_drain.nil? ? false : @skip_drain.for_job(name)
      end

      def add_stemcell(stemcell)
        @stemcells[stemcell.alias] = stemcell
      end

      def stemcell(name)
        @stemcells[name]
      end

      # Adds a release by name
      # @param [Bosh::Director::DeploymentPlan::ReleaseVersion] release
      def add_release(release)
        if @releases.has_key?(release.name)
          raise DeploymentDuplicateReleaseName,
            "Duplicate release name '#{release.name}'"
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

      def instance_plans_with_missing_vms
        jobs_starting_on_deploy.collect_concat do |job|
          job.instance_plans_with_missing_vms
        end
      end

      def mark_instance_for_deletion(instance)
        @unneeded_instances << instance
      end

      # Adds a job by name
      # @param [Bosh::Director::DeploymentPlan::Job] job
      def add_job(job)
        if @jobs_canonical_name_index.include?(job.canonical_name)
          raise DeploymentCanonicalJobNameTaken,
            "Invalid instance group name '#{job.name}', canonical name already taken"
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
        jobs = []

        @jobs.each do |job|
          if job.is_service?
            jobs << job
          elsif job.is_errand?
            if job.instances.any? { |i| nil != i.model && !i.model.vm_cid.to_s.empty? }
              jobs << job
            end
          end
        end

        jobs
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
        model.runtime_config = @runtime_config
        model.link_spec = @link_spec
        model.save
      end

      def update_stemcell_references!
        current_stemcell_models = resource_pools.map { |pool| pool.stemcell.model }
        @stemcells.values.map(&:model).each do |stemcell|
          current_stemcell_models << stemcell
        end
        model.stemcells.each do |deployment_stemcell|
          deployment_stemcell.remove_deployment(model) unless current_stemcell_models.include?(deployment_stemcell)
        end
      end

      def using_global_networking?
        !@cloud_config.nil?
      end

      private

      def validate_packages
        release_manager = Bosh::Director::Api::ReleaseManager.new
        validator = DeploymentPlan::PackageValidator.new(@logger)
        jobs.each do |job|
          job.templates.each do |template|
            release_model = release_manager.find_by_name(template.release.name)
            release_version_model = release_manager.find_version(release_model, template.release.version)

            validator.validate(release_version_model, job.stemcell.model)
          end
        end
        validator.handle_faults
      end
    end

    class CloudPlanner
      attr_accessor :compilation

      def initialize(options)
        @networks = self.class.index_by_name(options.fetch(:networks))
        @global_network_resolver = options.fetch(:global_network_resolver)
        @resource_pools = self.class.index_by_name(options.fetch(:resource_pools))
        @vm_types = self.class.index_by_name(options.fetch(:vm_types, {}))
        @vm_extensions = self.class.index_by_name(options.fetch(:vm_extensions, {}))
        @disk_types = self.class.index_by_name(options.fetch(:disk_types))
        @availability_zones = options.fetch(:availability_zones_list)
        @compilation = options.fetch(:compilation)
        @ip_provider_factory = options.fetch(:ip_provider_factory)
        @logger = options.fetch(:logger)
      end

      def ip_provider
        @ip_provider ||= @ip_provider_factory.new_ip_provider(@networks)
      end

      def model
        nil
      end

      def deleted_network(name)
        ManualNetwork.parse(
          {'subnets' => [], 'name' => name},
          [],
          @global_network_resolver,
          @logger
        )
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

      def vm_types
        @vm_types.values
      end

      def vm_type(name)
        @vm_types[name]
      end

      def vm_extensions
        @vm_extensions.values
      end

      def vm_extension(name)
        @vm_extensions[name]
      end

      def add_resource_pool(resource_pool)
        @resource_pools[resource_pool.name] = resource_pool
      end

      def networks
        @networks.values
      end

      def network(name)
        @networks[name]
      end

      def disk_types
        @disk_types.values
      end

      def using_global_networking?
        false
      end

      def disk_type(name)
        @disk_types[name]
      end

      def self.index_by_name(collection)
        collection.inject({}) do |index, item|
          index.merge(item.name => item)
        end
      end
    end
  end
end
