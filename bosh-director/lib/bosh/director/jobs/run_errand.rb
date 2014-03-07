require 'psych'

module Bosh::Director
  class Jobs::RunErrand < Jobs::BaseJob
    @queue = :normal

    def self.job_type
      :run_errand
    end

    def initialize(deployment_name, errand_name)
      @deployment_name = deployment_name
      @errand_name = errand_name
      @deployment_manager = Api::DeploymentManager.new
      @instance_manager = Api::InstanceManager.new
    end

    def perform
      deployment_model = @deployment_manager.find_by_name(@deployment_name)

      manifest = Psych.load(deployment_model.manifest)
      deployment = DeploymentPlan::Planner.parse(manifest, event_log, {})

      job = deployment.job(@errand_name)
      if job.nil?
        raise JobNotFound, "Errand `#{@errand_name}' doesn't exist"
      end

      if job.instances.empty?
        raise InstanceNotFound, "Instance `#{@deployment_name}/#{@errand_name}/0' doesn't exist"
      end

      runner = Errand::Runner.new(job, result_file, @instance_manager, event_log)
      runner.run
    end
  end
end
