module Bosh::Director
  module Jobs
    class UpdateDeployment < BaseJob
      include LockHelper

      @queue = :normal

      def self.job_type
        :update_deployment
      end

      # @param [String] manifest_file Path to deployment manifest
      # @param [Hash] options Deployment options
      def initialize(manifest_file, options = {})
        @blobstore = App.instance.blobstores.blobstore

        logger.info('Reading deployment manifest')
        @manifest_file = manifest_file
        @manifest = File.read(@manifest_file)
        logger.debug("Manifest:\n#{@manifest}")

        logger.info('Creating deployment plan')
        logger.info("Deployment plan options: #{options.pretty_inspect}")

        plan_options = {
          'recreate' => !!options['recreate'],
          'job_states' => options['job_states'] || {},
          'job_rename' => options['job_rename'] || {}
        }

        manifest_as_hash = Psych.load(@manifest)
        @deployment_plan = DeploymentPlan::Planner.parse(manifest_as_hash, event_log, plan_options)
        logger.info('Created deployment plan')

        resource_pools = @deployment_plan.resource_pools
        @resource_pool_updaters = resource_pools.map do |resource_pool|
          ResourcePoolUpdater.new(resource_pool)
        end
      end

      def prepare
        @assembler = DeploymentPlan::Assembler.new(@deployment_plan)
        preparer = DeploymentPlan::Preparer.new(self, @assembler)
        preparer.prepare

        logger.info('Compiling and binding packages')
        PackageCompiler.new(@deployment_plan).compile
      end

      def update
        resource_pools = DeploymentPlan::ResourcePools.new(event_log, @resource_pool_updaters)
        job_updater_factory = JobUpdaterFactory.new(@blobstore)
        multi_job_updater = DeploymentPlan::BatchMultiJobUpdater.new(job_updater_factory)
        updater = DeploymentPlan::Updater.new(self, event_log, resource_pools, @assembler, @deployment_plan, multi_job_updater)
        updater.update
      end

      def update_stemcell_references
        current_stemcells = Set.new
        @deployment_plan.resource_pools.each do |resource_pool|
          current_stemcells << resource_pool.stemcell.model
        end

        deployment = @deployment_plan.model
        stemcells = deployment.stemcells
        stemcells.each do |stemcell|
          unless current_stemcells.include?(stemcell)
            stemcell.remove_deployment(deployment)
          end
        end
      end

      def perform
        with_deployment_lock(@deployment_plan) do
          logger.info('Preparing deployment')
          prepare
          begin
            deployment = @deployment_plan.model
            logger.info('Finished preparing deployment')
            logger.info('Updating deployment')
            update

            with_release_locks(@deployment_plan) do
              deployment.db.transaction do
                deployment.remove_all_release_versions
                # Now we know that deployment has succeeded and can remove
                # previous partial deployments release version references
                # to be able to delete these release versions later.
                @deployment_plan.releases.each do |release|
                  deployment.add_release_version(release.model)
                end
              end
            end

            deployment.manifest = @manifest
            deployment.save
            logger.info('Finished updating deployment')
            "/deployments/#{deployment.name}"
          ensure
            update_stemcell_references
          end
        end
      ensure
        FileUtils.rm_rf(@manifest_file)
      end
    end
  end
end
