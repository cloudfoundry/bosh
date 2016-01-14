module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :update_deployment
      end

      def initialize(manifest_file_path, cloud_config_id, options = {})
        @blobstore = App.instance.blobstores.blobstore
        @manifest_file_path = manifest_file_path
        @options = options
        @cloud_config_id = cloud_config_id
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

        deployment_manifest = Manifest.load_from_text(manifest_text, cloud_config_model)
        deployment_name = deployment_manifest.to_hash['name']
        with_deployment_lock(deployment_name) do
          @notifier = DeploymentPlan::Notifier.new(deployment_name, Config.nats_rpc, logger)
          @notifier.send_start_event

          deployment_plan = nil

          event_log.begin_stage('Preparing deployment', 1)
          event_log.track('Preparing deployment') do
            planner_factory = DeploymentPlan::PlannerFactory.create(logger)
            deployment_plan = planner_factory.create_from_manifest(deployment_manifest, cloud_config_model, @options)
            deployment_plan.bind_models
          end

          deployment_plan.compile_packages

          render_job_templates(deployment_plan.jobs_starting_on_deploy)
          update_step(deployment_plan).perform
          @notifier.send_end_event
          logger.info('Finished updating deployment')

          "/deployments/#{deployment_plan.name}"
        end
      rescue Exception => e
        begin
          @notifier.send_error_event e
        rescue Exception => e2
          # log the second error
        ensure
          raise e
        end
      ensure
        FileUtils.rm_rf(@manifest_file_path)
      end

      private

      # Job tasks

      def update_step(deployment_plan)
        DeploymentPlan::Steps::UpdateStep.new(
          self,
          event_log,
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
        job_renderer = JobRenderer.create
        jobs.each do |job|
          job_renderer.render_job_instances(job.needed_instance_plans)
        end
      end
    end
  end
end
