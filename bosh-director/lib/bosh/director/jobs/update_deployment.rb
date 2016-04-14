module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :update_deployment
      end

      def initialize(manifest_file_path, cloud_config_id, runtime_config_id, options = {})
        @blobstore = App.instance.blobstores.blobstore
        @manifest_file_path = manifest_file_path
        @cloud_config_id = cloud_config_id
        @runtime_config_id = runtime_config_id
        @options = options
      end

      def perform
        logger.info('Reading deployment manifest')

        manifest_text = File.read(@manifest_file_path)
        logger.debug("Manifest:\n#{manifest_text}")
        cloud_config_model = Bosh::Director::Models::CloudConfig[@cloud_config_id]
        if cloud_config_model.nil?
          logger.debug("No cloud config uploaded yet.")
        else
          logger.debug("Cloud config:\n#{cloud_config_model.manifest}")
        end

        runtime_config_model = Bosh::Director::Models::RuntimeConfig[@runtime_config_id]
        if runtime_config_model.nil?
          logger.debug("No runtime config uploaded yet.")
        else
          logger.debug("Runtime config:\n#{runtime_config_model.manifest}")
        end

        deployment_manifest = Manifest.load_from_text(manifest_text, cloud_config_model, runtime_config_model)
        @deployment_name = deployment_manifest.to_hash['name']
        parent_id = add_event

        with_deployment_lock(@deployment_name) do
          @notifier = DeploymentPlan::Notifier.new(@deployment_name, Config.nats_rpc, logger)
          @notifier.send_start_event

          deployment_plan = nil

          event_log_stage = Config.event_log.begin_stage('Preparing deployment', 1)
          event_log_stage.advance_and_track('Preparing deployment') do
            planner_factory = DeploymentPlan::PlannerFactory.create(logger)
            deployment_plan = planner_factory.create_from_manifest(deployment_manifest, cloud_config_model, runtime_config_model, @options)
            deployment_plan.bind_models
          end

          render_job_templates(deployment_plan.jobs_starting_on_deploy)
          deployment_plan.compile_packages

          update_step(deployment_plan).perform

          if check_for_changes(deployment_plan)
            PostDeploymentScriptRunner.run_post_deploys_after_deployment(deployment_plan)
          end

          @notifier.send_end_event
          logger.info('Finished updating deployment')
          add_event(parent_id)

          "/deployments/#{deployment_plan.name}"
        end
      rescue Exception => e
        begin
          @notifier.send_error_event e
        rescue Exception => e2
          # log the second error
        ensure
          add_event(parent_id, e)
          raise e
        end
      ensure
        FileUtils.rm_rf(@manifest_file_path)
      end

      private

      def add_event(parent_id = nil, error = nil)
        action = deployment_new? ? "create" : "update"
        event  = event_manager.create_event(
            {
                parent_id:   parent_id,
                user:        username,
                action:      action,
                object_type: "deployment",
                object_name: @deployment_name,
                deployment:  @deployment_name,
                task:        task_id,
                error:       error
            })
        event.id
      end

      # Job tasks

      def check_for_changes(deployment_plan)
        deployment_plan.jobs.each do |job|
          return true if job.did_change
        end
        false
      end

      def update_step(deployment_plan)
        DeploymentPlan::Steps::UpdateStep.new(
          self,
          deployment_plan,
          multi_job_updater,
          Config.cloud
        )
      end

      # Job dependencies

      def multi_job_updater
        @multi_job_updater ||= begin
          DeploymentPlan::BatchMultiJobUpdater.new(JobUpdaterFactory.new(Config.cloud, logger))
        end
      end

      def render_job_templates(jobs)
        errors = []
        job_renderer = JobRenderer.create
        jobs.each do |job|
          begin
            job_renderer.render_job_instances(job.needed_instance_plans)
          rescue Exception => e
            errors.push e
          end
        end

        if errors.length > 0
          message = 'Unable to render instance groups for deployment. Errors are:'

          errors.each do |e|
            message = "#{message}\n   - #{e.message.gsub(/\n/, "\n  ")}"
          end

          raise message
        end
      end

      def deployment_new?
        @deployment_new ||= Models::Deployment.exclude(manifest: nil)[name: @deployment_name].nil?
      end
    end
  end
end
