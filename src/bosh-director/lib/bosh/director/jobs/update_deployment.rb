module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      include LockHelper
      include LegacyDeploymentHelper

      @queue = :normal

      def self.job_type
        :update_deployment
      end

      def initialize(manifest_text, cloud_config_ids, runtime_config_ids, options = {})
        @blobstore = App.instance.blobstores.blobstore
        @manifest_text = manifest_text
        @cloud_config_ids = cloud_config_ids
        @runtime_config_ids = runtime_config_ids
        @options = options
        @event_log = Config.event_log
        @variables_interpolator = ConfigServer::VariablesInterpolator.new
      end

      def dry_run?
        true if @options['dry_run']
      end

      def perform
        logger.info('Reading deployment manifest')
        manifest_hash = YAML.load(@manifest_text)
        logger.debug("Manifest:\n#{@manifest_text}")

        if ignore_cloud_config?(manifest_hash)
          warning = "Ignoring cloud config. Manifest contains 'networks' section."
          logger.debug(warning)
          @event_log.warn_deprecated(warning)
          cloud_config_models = nil
        else
          cloud_config_models = Bosh::Director::Models::Config.find_by_ids(@cloud_config_ids)
          if cloud_config_models.empty?
            logger.debug('No cloud config uploaded yet.')
          else
            logger.debug("Cloud config:\n#{Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_config_models).raw_manifest}")
          end
        end

        runtime_config_models = Bosh::Director::Models::Config.find_by_ids(@runtime_config_ids)
        if runtime_config_models.empty?
          logger.debug("No runtime config uploaded yet.")
        else
          logger.debug("Runtime configs:\n#{Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_config_models).raw_manifest}")
        end

        @deployment_name = manifest_hash['name']

        previous_releases, previous_stemcells = get_stemcells_and_releases
        context = {}
        parent_id = add_event

        with_deployment_lock(@deployment_name) do
          is_deploy_action = @options['deploy']
          deployment_plan = nil
          dns_encoder = nil

          if is_deploy_action
            deployment_model = Bosh::Director::Models::Deployment.find(name: @deployment_name)

            deployment_model.add_variable_set(:created_at => Time.now, :writable => true)

            deployment_model.links_serial_id += 1
            deployment_model.save
          end

          manifest_text = @options.fetch('manifest_text', @manifest_text)
          deployment_manifest_object = Manifest.load_from_hash(manifest_hash, manifest_text, cloud_config_models, runtime_config_models)

          @notifier = DeploymentPlan::Notifier.new(@deployment_name, Config.nats_rpc, logger)
          @notifier.send_start_event unless dry_run?

          event_log_stage = @event_log.begin_stage('Preparing deployment', 1)
          event_log_stage.advance_and_track('Preparing deployment') do
            planner_factory = DeploymentPlan::PlannerFactory.create(logger)

            # that's where the link path is created
            deployment_plan = planner_factory.create_from_manifest(deployment_manifest_object, cloud_config_models, runtime_config_models, @options)
            @links_manager = Bosh::Director::Links::LinksManager.new(deployment_plan.model.links_serial_id)
            create_network_stage(deployment_plan).perform unless dry_run?

            deployment_assembler = DeploymentPlan::Assembler.create(deployment_plan, @variables_interpolator)
            dns_encoder = LocalDnsEncoderManager.new_encoder_with_updated_index(deployment_plan)

            # that's where the links resolver is created
            deployment_assembler.bind_models({is_deploy_action: is_deploy_action, should_bind_new_variable_set: is_deploy_action})
          end

          if deployment_plan.instance_models.any?(&:ignore)
            @event_log.warn('You have ignored instances. They will not be changed.')
          end

          next_releases, next_stemcells = get_stemcells_and_releases
          context = event_context(next_releases, previous_releases, next_stemcells, previous_stemcells)

          begin
            current_variable_set = deployment_plan.model.current_variable_set

            render_templates_and_snapshot_errand_variables(deployment_plan, current_variable_set, dns_encoder)

            return "/deployments/#{deployment_plan.name}" if dry_run?

            compilation_step(deployment_plan).perform

            update_stage(deployment_plan, dns_encoder).perform

            PostDeploymentScriptRunner.run_post_deploys_after_deployment(deployment_plan) if check_for_changes(deployment_plan)

            # only in the case of a deploy should you be cleaning up
            if is_deploy_action
              @links_manager.remove_unused_links(deployment_plan.model)
              current_variable_set.update(deployed_successfully: true)
              remove_unused_variable_sets(deployment_plan.model, deployment_plan.instance_groups)
              mark_orphaned_networks(deployment_plan)
            end

            @notifier.send_end_event
            logger.info('Finished updating deployment')
            add_event(context, parent_id)

            "/deployments/#{deployment_plan.name}"
          ensure
            deployment_plan.template_blob_cache.clean_cache!
          end
        end
      rescue Exception => e
        begin
          @notifier.send_error_event e unless dry_run?
        rescue Exception => e2
          # ignore the second error
        ensure
          add_event(context, parent_id, e)
          raise e
        end
      ensure
        current_deployment&.current_variable_set&.update(writable: false) if @options['deploy']
      end

      private

      def mark_orphaned_networks(deployment_plan)
        return unless Config.network_lifecycle_enabled?

        deployment_model = deployment_plan.model
        deployment_networks = []

        deployment_plan.instance_groups.each do |inst_group|
          inst_group.networks.each do |jobnetwork|
            network = jobnetwork.deployment_network
            next unless network.managed?
            deployment_networks << jobnetwork.deployment_network.name
          end
        end

        deployment_model.networks.each do |network|
          with_network_lock(network.name) do
            next if deployment_networks.include?(network.name)

            deployment_model.remove_network(network)
            if network.deployments.empty?
              @logger.info("Orphaning managed network #{network.name}")
              network.orphaned = true
              network.orphaned_at = Time.now
              network.save
            end
          end
        end
      end

      def remove_unused_variable_sets(deployment, instance_groups)
        variable_sets_to_keep = []
        variable_sets_to_keep << deployment.current_variable_set
        instance_groups.each do |instance_group|
          variable_sets_to_keep += instance_group.referenced_variable_sets
        end

        begin
          deployment.cleanup_variable_sets(variable_sets_to_keep.uniq)
        rescue Sequel::ForeignKeyConstraintViolation => e
          logger.warn("Unable to clean up variable_sets. Error: #{e.inspect}")
        end
      end

      def add_event(context = {}, parent_id = nil, error = nil)
        action = @options.fetch('new', false) ? 'create' : 'update'
        event = event_manager.create_event(
          parent_id: parent_id,
          user: username,
          action: action,
          object_type: 'deployment',
          object_name: @deployment_name,
          deployment: @deployment_name,
          task: task_id,
          error: error,
          context: context,
        )
        event.id
      end

      # Job tasks

      def check_for_changes(deployment_plan)
        deployment_plan.instance_groups.each do |job|
          return true if job.did_change
        end
        false
      end

      def compilation_step(deployment_plan)
        DeploymentPlan::Stages::PackageCompileStage.create(deployment_plan)
      end

      def create_network_stage(deployment_plan)
        DeploymentPlan::Stages::CreateNetworkStage.new(Config.logger, deployment_plan)
      end

      def update_stage(deployment_plan, dns_encoder)
        DeploymentPlan::Stages::UpdateStage.new(
          self,
          deployment_plan,
          multi_instance_group_updater(deployment_plan, dns_encoder),
          dns_encoder
        )
      end

      # Job dependencies

      def multi_instance_group_updater(deployment_plan, dns_encoder)
        @multi_instance_group_updater ||= begin
          DeploymentPlan::BatchMultiInstanceGroupUpdater.new(InstanceGroupUpdaterFactory.new(logger, deployment_plan.template_blob_cache, dns_encoder))
        end
      end

      def render_templates_and_snapshot_errand_variables(deployment_plan, current_variable_set, dns_encoder)
        errors = render_instance_groups_templates(deployment_plan.instance_groups_starting_on_deploy, deployment_plan.template_blob_cache, dns_encoder)
        errors += snapshot_errands_variables_versions(deployment_plan.errand_instance_groups, current_variable_set)

        unless errors.empty?
          message = errors.map { |error| error.message.strip }.join("\n")
          header = 'Unable to render instance groups for deployment. Errors are:'
          raise Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(
            header,
            message,
            indent_by: 2,
          )
        end
      end

      def render_instance_groups_templates(instance_groups, template_blob_cache, dns_encoder)
        errors = []
        instance_groups.each do |instance_group|
          begin
            JobRenderer.render_job_instances_with_cache(
              instance_group.unignored_instance_plans,
              template_blob_cache,
              dns_encoder,
              logger,
            )
          rescue Exception => e
            errors.push e
          end
        end
        errors
      end

      def snapshot_errands_variables_versions(errands_instance_groups, current_variable_set)
        errors = []

        errands_instance_groups.each do |instance_group|
          instance_group_errors = []

          begin
            @variables_interpolator.interpolate_template_spec_properties(instance_group.properties, @deployment_name, current_variable_set)
            unless instance_group&.env&.spec.nil?
              @variables_interpolator.interpolate_with_versioning(instance_group.env.spec, current_variable_set)
            end
          rescue Exception => e
            instance_group_errors.push e
          end

          deployment = Bosh::Director::Models::Deployment.where(name: @deployment_name).first
          instance_group_links = @links_manager.get_links_for_instance_group(deployment, instance_group.name) || {}
          instance_group_links.each do |job_name, links|
            begin
              @variables_interpolator.interpolate_link_spec_properties(links || {}, current_variable_set)
            rescue Exception => e
              instance_group_errors.push e
            end
          end

          unless instance_group_errors.empty?
            message = instance_group_errors.map { |error| error.message.strip }.join("\n")
            header = "- Unable to render jobs for instance group '#{instance_group.name}'. Errors are:"
            e = Exception.new(Bosh::Director::FormatterHelper.new.prepend_header_and_indent_body(header, message, {:indent_by => 2}))
            errors << e
          end

          if errors.empty?
            instance_group.instances.each do |instance|
              @links_manager.bind_links_to_instance(instance)
            end
          end
        end
        errors
      end

      def get_stemcells_and_releases
        deployment = current_deployment
        stemcells = []
        releases = []
        if deployment
          releases = deployment.release_versions.map do |rv|
            "#{rv.release.name}/#{rv.version}"
          end
          stemcells = deployment.stemcells.map do |sc|
            "#{sc.name}/#{sc.version}"
          end
        end

        [releases, stemcells]
      end

      def current_deployment
        Models::Deployment[name: @deployment_name]
      end

      def event_context(next_releases, previous_releases, next_stemcells, previous_stemcells)
        after_objects = {}
        after_objects['releases'] = next_releases unless next_releases.empty?
        after_objects['stemcells'] = next_stemcells unless next_stemcells.empty?

        before_objects = {}
        before_objects['releases'] = previous_releases unless previous_releases.empty?
        before_objects['stemcells'] = previous_stemcells unless previous_stemcells.empty?

        context = {}
        context['before'] = before_objects
        context['after'] = after_objects
        context
      end
    end
  end
end
