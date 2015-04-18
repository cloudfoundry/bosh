module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      @queue = :normal

      def self.job_type
        :update_deployment
      end

      def initialize(manifest_file_path, options = {})
        @blobstore = App.instance.blobstores.blobstore
        @manifest_file_path = manifest_file_path
        @options = options
      end

      def perform
        with_deployment_lock(deployment_plan) do
          logger.info('Updating deployment')
          notifier.send_start_event
          prepare
          compile
          update
          notifier.send_end_event
          logger.info('Finished updating deployment')

          "/deployments/#{deployment_plan.name}"
        end
      rescue Exception => e
        notifier.send_error_event e
        raise e
      ensure
        FileUtils.rm_rf(@manifest_file_path)
      end

      # Job tasks

      def prepare
        prepare_step = DeploymentPlan::Preparer.new(self, assembler)
        prepare_step.prepare
      end

      def compile
        compile_step = PackageCompiler.new(self, deployment_plan)
        compile_step.compile
      end

      def update
        resource_pool_updaters = deployment_plan.resource_pools.map do |resource_pool|
          ResourcePoolUpdater.new(resource_pool)
        end
        resource_pools = DeploymentPlan::ResourcePools.new(event_log, resource_pool_updaters)
        update_step = DeploymentPlan::Updater.new(self, event_log, resource_pools, assembler, deployment_plan, deployment_plan.model, multi_job_updater)
        update_step.update
      end

      # Job dependencies

      def assembler
        @assembler ||= DeploymentPlan::Assembler.new(deployment_plan)
      end

      def notifier
        @notifier ||= DeploymentPlan::Notifier.new(deployment_plan, Config.nats_rpc, logger)
      end

      def deployment_plan
        @deployment_plan ||= begin
          logger.info('Reading deployment manifest')
          manifest_text = File.read(@manifest_file_path)
          logger.debug("Manifest:\n#{manifest_text}")
          deployment_manifest = Psych.load(manifest_text)

          plan_options = {
            'recreate' => !!@options['recreate'],
            'job_states' => @options['job_states'] || {},
            'job_rename' => @options['job_rename'] || {}
          }
          logger.info('Creating deployment plan')
          logger.info("Deployment plan options: #{plan_options.pretty_inspect}")

          plan = DeploymentPlan::Planner.parse(deployment_manifest, plan_options, event_log, logger)
          logger.info('Created deployment plan')
          plan
        end
      end

      def multi_job_updater
        @multi_job_updater ||= begin
          DeploymentPlan::BatchMultiJobUpdater.new(JobUpdaterFactory.new(@blobstore))
        end
      end
    end
  end
end
