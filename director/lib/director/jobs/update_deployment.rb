module Bosh::Director
  module Jobs
    class UpdateDeployment
      extend BaseJob

      @queue = :normal

      def initialize(manifest_file)
        @logger = Config.logger
        @logger.info("Reading deployment manifest")
        @manifest_file = manifest_file
        @manifest = File.open(@manifest_file) {|f| f.read}
        @logger.debug("Manifest:\n#{@manifest}")
        @logger.info("Creating deployment plan")
        @deployment_plan = DeploymentPlan.new(YAML.load(@manifest))
        @logger.info("Created deployment plan")
      end

      def find_or_create_deployment(name)
        deployment = Models::Deployment.find(:name => name).first
        if deployment.nil?
          deployment = Models::Deployment.new
          deployment.name = name
          deployment.save!
        end
        deployment
      end

      def prepare
        @logger.info("Looking up deployment record")
        deployment = find_or_create_deployment(@deployment_plan.name)
        @deployment_plan.deployment = deployment
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)

        @logger.info("Binding release")
        @deployment_plan_compiler.bind_release
        @logger.info("Binding existing deployment")
        @deployment_plan_compiler.bind_existing_deployment
        @logger.info("Binding resource pools")
        @deployment_plan_compiler.bind_resource_pools
        @logger.info("Binding stemcells")
        @deployment_plan_compiler.bind_stemcells
        @logger.info("Binding jobs")
        @deployment_plan_compiler.bind_jobs
        @logger.info("Binding instance networks")
        @deployment_plan_compiler.bind_instance_networks

        @logger.info("Compiling packages")
        PackageCompiler.new(@deployment_plan).compile

        @logger.info("Binding packages")
        @deployment_plan_compiler.bind_packages
        @logger.info("Binding configuration")
        @deployment_plan_compiler.bind_configuration
      end

      def update
        @logger.info("Updating resource pools")
        @deployment_plan.resource_pools.each do |resource_pool|
          @logger.info("Updating resource pool: #{resource_pool.name}")
          ResourcePoolUpdater.new(resource_pool).update
        end

        @logger.info("Binding instance VMs")
        @deployment_plan_compiler.bind_instance_vms

        @logger.info("Deleting no longer needed VMs")
        @deployment_plan_compiler.delete_unneeded_vms

        @logger.info("Deleting no longer needed instances")
        @deployment_plan_compiler.delete_unneeded_instances

        @logger.info("Updating jobs")
        @deployment_plan.jobs.each do |job|
          @logger.info("Updating job: #{job.name}")
          JobUpdater.new(job).update
        end
      end

      def rollback
        if @deployment_plan.deployment.manifest
          @manifest = @deployment_plan.deployment.manifest
          @deployment_plan = DeploymentPlan.new(YAML.load(@manifest))
          prepare
          update
        else
          @logger.info("Nothing to rollback to since this is the initial deployment")
        end
      end

      def perform
        @logger.info("Acquiring deployment lock: #{@deployment_plan.name}")
        deployment_lock = Lock.new("lock:deployment:#{@deployment_plan.name}")
        deployment_lock.lock do
          @logger.info("Acquiring release lock: #{@deployment_plan.release.name}")
          release_lock = Lock.new("lock:release:#{@deployment_plan.release.name}")
          release_lock.lock do
            @logger.info("Preparing deployment")
            prepare
            deployment = @deployment_plan.deployment
            @logger.info("Finished preparing deployment")
            begin
              @logger.info("Updating deployment")
              update
              deployment.manifest = @manifest
              deployment.save!
              @logger.info("Finished updating deployment")
              "/deployments/#{deployment.name}"
            rescue Exception => e
              @logger.info("Update failed, rolling back")
              @logger.error("#{e} - #{e.backtrace.join("\n")}")
              # TODO: record the error
              rollback
            end
          end
        end
      ensure
        FileUtils.rm_rf(@manifest_file)
      end
    end
  end
end
