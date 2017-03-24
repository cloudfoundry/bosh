require 'bosh/director/deployment_plan/deployment_spec_parser'
require 'bosh/director/deployment_plan/cloud_manifest_parser'
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

      # @return [Bosh::Director::DeploymentPlan::UpdateConfig]
      #   Default job update configuration
      attr_accessor :update

      # @return [Array<Bosh::Director::DeploymentPlan::Job>]
      #   All instance_groups in the deployment
      attr_reader :instance_groups

      # Stemcells in deployment by alias
      attr_reader :stemcells

      # Tags in deployment by alias
      attr_reader :tags

      # Job instances from the old manifest that are not in the new manifest
      attr_reader :unneeded_instance_plans

      # @return [Boolean] Indicates whether VMs should be recreated
      attr_reader :recreate

      attr_writer :cloud_planner

      # @return [Boolean] Indicates whether VMs should be drained
      attr_reader :skip_drain

      attr_reader :uninterpolated_manifest_text

      # @return [DeploymentPlan::Variables] Returns the variables object of deployment
      attr_reader :variables

      attr_reader :job_renderer

      def initialize(attrs, uninterpolated_manifest_text, cloud_config, runtime_config, deployment_model, options = {})
        @name = attrs.fetch(:name)
        @properties = attrs.fetch(:properties)
        @releases = {}

        @uninterpolated_manifest_text = Bosh::Common::DeepCopy.copy(uninterpolated_manifest_text)
        @cloud_config = cloud_config
        @runtime_config = runtime_config
        @model = deployment_model

        @stemcells = {}
        @instance_groups = []
        @instance_groups_name_index = {}
        @instance_groups_canonical_name_index = Set.new
        @tags = options.fetch('tags', {})

        @unneeded_vms = []
        @unneeded_instance_plans = []

        @recreate = !!options['recreate']
        @fix = !!options['fix']

        @link_spec = {}
        @skip_drain = SkipDrain.new(options['skip_drain'])

        @variables = Variables.new([])

        @logger = Config.logger
        @job_renderer = JobRenderer.create
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

      def bind_models(options = {})
        stemcell_manager = Api::StemcellManager.new
        dns_manager = DnsManagerProvider.create
        assembler = DeploymentPlan::Assembler.new(
          self,
          stemcell_manager,
          dns_manager,
          @logger
        )

        options[:fix] = @fix
        options[:tags] = @tags
        assembler.bind_models(options)
      end

      def compile_packages
        validate_packages

        disk_manager = DiskManager.new(@logger)
        agent_broadcaster = AgentBroadcaster.new
        dns_manager = DnsManagerProvider.create
        vm_deleter = VmDeleter.new(@logger, false, Config.enable_virtual_delete_vms)
        vm_creator = Bosh::Director::VmCreator.new(@logger, vm_deleter, disk_manager, @job_renderer, agent_broadcaster)
        instance_deleter = Bosh::Director::InstanceDeleter.new(ip_provider, dns_manager, disk_manager)
        compilation_instance_pool = CompilationInstancePool.new(
          InstanceReuser.new,
          vm_creator,
          self,
          @logger,
          instance_deleter,
          compilation.workers)
        package_compile_step = DeploymentPlan::Steps::PackageCompileStep.new(
          @name,
          instance_groups,
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
        desired_job_names = instance_groups.map(&:name)
        migrating_job_names = instance_groups.map(&:migrated_from).flatten.map(&:name)

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
        instance_groups_starting_on_deploy.collect_concat do |instance_group|
          instance_group.instance_plans_with_missing_vms
        end
      end

      def mark_instance_plans_for_deletion(instance_plans)
        @unneeded_instance_plans = instance_plans
      end

      def unneeded_instances
        @unneeded_instance_plans.map(&:existing_instance)
      end

      # Adds a instance_group by name
      # @param [Bosh::Director::DeploymentPlan::InstanceGroup] instance_group
      def add_instance_group(instance_group)
        if @instance_groups_canonical_name_index.include?(instance_group.canonical_name)
          raise DeploymentCanonicalJobNameTaken,
            "Invalid instance group name '#{instance_group.name}', canonical name already taken"
        end

        @instance_groups << instance_group
        @instance_groups_name_index[instance_group.name] = instance_group
        @instance_groups_canonical_name_index << instance_group.canonical_name
      end

      # Returns a named instance_group
      # @param [String] name Instance group name
      # @return [Bosh::Director::DeploymentPlan::InstanceGroup] Instance group
      def instance_group(name)
        @instance_groups_name_index[name]
      end

      def instance_groups_starting_on_deploy
        instance_groups = []

        @instance_groups.each do |instance_group|
          if instance_group.is_service?
            instance_groups << instance_group
          elsif instance_group.is_errand?
            if instance_group.instances.any? { |i| nil != i.model && !i.model.vm_cid.to_s.empty? }
              instance_groups << instance_group
            end
          end
        end

        instance_groups
      end

      # @return [Array<Bosh::Director::DeploymentPlan::InstanceGroup>] InstanceGroups with errand lifecycle
      def errand_instance_groups
        @instance_groups.select(&:is_errand?)
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

        model.manifest = YAML.dump(@uninterpolated_manifest_text)
        model.cloud_config = @cloud_config
        model.runtime_config = @runtime_config
        model.link_spec = @link_spec
        model.save
      end

      def update_stemcell_references!
        current_stemcell_models = resource_pools.map { |pool| pool.stemcell.models }.flatten
        @stemcells.values.map(&:models).flatten.each do |stemcell|
          current_stemcell_models << stemcell
        end
        model.stemcells.each do |deployment_stemcell|
          deployment_stemcell.remove_deployment(model) unless current_stemcell_models.include?(deployment_stemcell)
        end
      end

      def using_global_networking?
        !@cloud_config.nil?
      end

      # If we don't want to do what we are doing in this method, then link_spec should be an object
      def add_deployment_link_spec(instance_group_name, job_name, provided_link_name, provided_link_type, link_spec)
        @link_spec[instance_group_name] ||= {}
        @link_spec[instance_group_name][job_name] ||= {}
        @link_spec[instance_group_name][job_name][provided_link_name] ||= {}
        @link_spec[instance_group_name][job_name][provided_link_name][provided_link_type] = link_spec
      end

      def set_variables(variables_obj)
        @variables = variables_obj
      end

      private

      def validate_packages
        release_manager = Bosh::Director::Api::ReleaseManager.new
        validator = DeploymentPlan::PackageValidator.new(@logger)
        instance_groups.each do |instance_group|
          instance_group.jobs.each do |job|
            release_model = release_manager.find_by_name(job.release.name)
            release_version_model = release_manager.find_version(release_model, job.release.version)

            validator.validate(release_version_model, instance_group.stemcell)
          end
        end
        validator.handle_faults
      end
    end
  end
end
