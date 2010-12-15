module Bosh::Director

  module Jobs

    class UpdateDeployment

      @queue = :normal

      def self.perform(task_id, manifest_file)
        UpdateDeployment.new(task_id, manifest_file).perform
      end

      def initialize(task_id, manifest_file)
        @task = Models::Task[task_id]
        raise TaskNotFound if @task.nil?

        @logger = Logger.new(@task.output)
        @logger.level = Config.logger.level
        @logger.formatter = ThreadFormatter.new
        @logger.info("Starting task: #{task_id}")
        Config.logger = @logger

        begin
          @logger.info("Reading deployment manifest")
          @manifest_file = manifest_file
          @manifest = File.open(@manifest_file) {|f| f.read}
          @logger.debug("Manifest:\n#{@manifest}")
          @logger.info("Creating deployment plan")
          @deployment_plan = DeploymentPlan.new(YAML.load(@manifest))
          @logger.info("Created deployment plan")
        rescue Exception => e
          @logger.error("#{e} - #{e.backtrace.join("\n")}")
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save!
          raise e
        end
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
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save!

        begin
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
              rescue Exception => e
                @logger.info("Update failed, rolling back")
                @logger.error("#{e} - #{e.backtrace.join("\n")}")
                rollback
                # TODO: record the error
              end

              @task.state = :done
              # TODO: generate result
              @task.timestamp = Time.now.to_i
              @task.save!
              @logger.info("Done")
            end
          end
        rescue Exception => e
          @logger.error("#{e} - #{e.backtrace.join("\n")}")
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save!
        ensure
          FileUtils.rm_rf(@manifest_file)
        end
      end

    end
  end
end
