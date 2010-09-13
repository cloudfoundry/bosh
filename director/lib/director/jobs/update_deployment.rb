module Bosh::Director

  module Jobs

    class UpdateDeployment

      @queue = :normal

      def self.perform(task_id, manifest_file)
        UpdateDeployment.new(task_id, manifest_file).perform
      end

      def initialize(task_id, manifest_file)
        @task = Models::Task[task_id]
        raise TaskInvalid if @task.nil?

        @manifest_file = manifest_file
        @manifest = File.open(@manifest_file) {|f| f.read}
        @deployment_plan = DeploymentPlan.new(YAML.load(@manifest))
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
        deployment = find_or_create_deployment(@deployment_plan.name)
        @deployment_plan.deployment = deployment
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)

        @deployment_plan_compiler.bind_existing_deployment
        @deployment_plan_compiler.bind_resource_pools
        @deployment_plan_compiler.bind_instance_networks

        PackageCompiler.new(@deployment_plan).compile

        @deployment_plan_compiler.bind_packages
        @deployment_plan_compiler.bind_configuration
      end

      def update
        @deployment_plan.resource_pools.each do |resource_pool|
          ResourcePoolUpdater.new(resource_pool).update
        end

        @deployment_plan_compiler.bind_instance_vms

        @deployment_plan_compiler.delete_unneeded_vms
        @deployment_plan_compiler.delete_unneeded_instances

        @deployment_plan.jobs.each do |job|
          JobUpdater.new(job).update
        end
      end

      def rollback
        if @deployment_plan.deployment.manifest
          @manifest = @deployment_plan.deployment.manifest
          @deployment_plan = DeploymentPlan.new(YAML.load(@manifest))
          prepare
          update
        end
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save!

        begin
          deployment_lock = Lock.new("lock:deployment:#{@deployment_plan.name}")
          deployment_lock.lock do
            release_lock = Lock.new("lock:release:#{@deployment_plan.release.name}")
            release_lock.lock do
              prepare
              deployment = @deployment_plan.deployment

              begin
                update
                deployment.manifest = @manifest
                deployment.save!
              rescue Exception => e
                rollback
                # TODO: record the error
              end

              @task.state = :done
              # TODO: generate result
              @task.timestamp = Time.now.to_i
              @task.save!
            end
          end
        rescue => e
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save!
        ensure
          # TODO: cleanup?
        end
      end

    end
  end
end
