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
      end

      def find_or_create_deployment(name)
        deployment = Models::Deployment.find(:name => name).first
        if deployment.nil?
          deployment = Models::Deployment.new(:name => name)
          deployment.save
        end
        deployment
      end

      def compile_packages
        uncompiled_packages = []
        release_version = @deployment_plan.release.release
        @deployment_plan.jobs.each do |job|
          stemcell = job.resource_pool.stemcell.stemcell
          template = Models::Template.find(:release_version_id => release_version.id, :name => job.template).first
          template.packages.each do |package|
            job.packages[package.name] = package.version 
            compiled_package = Models::CompiledPackage.find(:package_id => package.id,
                                                            :stemcell_id => stemcell.id).first
            unless compiled_package
              uncompiled_packages << {
                :package => package,
                :stemcell => stemcell
              }
            end
          end
        end

        PackageCompiler.new(uncompiled_packages).compile unless uncompiled_packages.empty?
      end

      def prepare
        deployment = find_or_create_deployment(@deployment_plan.name)
        @deployment_plan.deployment = deployment
        @deployment_plan_compiler = DeploymentPlanCompiler.new(@deployment_plan)
        
        @deployment_plan_compiler.bind_existing_deployment
        @deployment_plan_compiler.bind_resource_pools
        @deployment_plan_compiler.bind_instance_networks

        compile_packages
        @deployment_plan_compiler.bind_packages
      end

      def update
        @deployment_plan.resource_pools.each do |resource_pool|
          ResourcePoolUpdater.new(resource_pool).update
        end

        @deployment_plan_compiler.bind_instance_vms

        @deployment_plan.jobs.each do |job|
          JobUpdater.new(job).update
        end
      end

      def perform
        @task.state = :processing
        @task.timestamp = Time.now.to_i
        @task.save

        @deployment_plan = DeploymentPlan.new(YAML.load_file(@manifest_file))

        begin
          deployment_lock = Lock.new("lock:deployment:#{@deployment_plan.name}")
          deployment_lock.lock do
            release_lock = Lock.new("lock:release:#{@deployment_plan.release.name}")
            release_lock.lock do
              prepare
              deployment = @deployment_plan.deployment

              begin
                update
                deployment.manifest = File.open(@manifest_file) {|f| f.read}
                deployment.save!
              rescue Exception
                # Rollback to the previous deployment manifest if it exists
                if deployment.manifest
                  @deployment_plan = DeploymentPlan.new(YAML.load(deployment.manifest))
                  prepare
                  update
                end
              end

              @task.state = :done
              # TODO: generate result
              @task.timestamp = Time.now.to_i
              @task.save
            end
          end
        rescue => e
          @task.state = :error
          @task.result = e.to_s
          @task.timestamp = Time.now.to_i
          @task.save

          raise e
        ensure
          # TODO: cleanup?
        end
      end

    end
  end
end
