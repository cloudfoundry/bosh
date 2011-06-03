module Bosh::Director
  module Jobs
    class UpdateDeployment
      extend BaseJob

      @queue = :normal

      def initialize(manifest_file, options = {})
        @logger = Config.logger
        @logger.info("Reading deployment manifest")
        @manifest_file = manifest_file
        @manifest = File.open(@manifest_file) { |f| f.read }
        @logger.debug("Manifest:\n#{@manifest}")
        @logger.info("Creating deployment plan")
        @deployment_plan = DeploymentPlan.new(YAML.load(@manifest), options["recreate"] || false)
        @logger.info("Created deployment plan")
      end

      def prepare
        @logger.info("Looking up deployment record")
        @deployment_plan.deployment = Models::Deployment.find_or_create(:name => @deployment_plan.name)
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)

        @logger.info("Binding release")
        @deployment_plan_compiler.bind_release
        @logger.info("Binding existing deployment")
        @deployment_plan_compiler.bind_existing_deployment
        @logger.info("Binding resource pools")
        @deployment_plan_compiler.bind_resource_pools
        @logger.info("Binding stemcells")
        @deployment_plan_compiler.bind_stemcells
        @logger.info("Binding templates")
        @deployment_plan_compiler.bind_templates
        @logger.info("Binding unallocated VMs")
        @deployment_plan_compiler.bind_unallocated_vms
        @logger.info("Binding instance networks")
        @deployment_plan_compiler.bind_instance_networks
        @logger.info("Compiling and binding packages")
        PackageCompiler.new(@deployment_plan).compile
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

      def update_stemcell_references
        current_stemcells = Set.new
        @deployment_plan.resource_pools.each do |resource_pool|
          current_stemcells << resource_pool.stemcell.stemcell
        end

        deployment = @deployment_plan.deployment
        stemcells = deployment.stemcells
        stemcells.each do |stemcell|
          unless current_stemcells.include?(stemcell)
            stemcell.remove_deployment(deployment)
          end
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
            begin
              deployment = @deployment_plan.deployment
              @logger.info("Finished preparing deployment")
              @logger.info("Updating deployment")
              update
              deployment.manifest = @manifest
              deployment.save
              @logger.info("Finished updating deployment")
              "/deployments/#{deployment.name}"
            ensure
              update_stemcell_references
            end
          end
        end
      ensure
        FileUtils.rm_rf(@manifest_file)
      end
    end
  end
end
