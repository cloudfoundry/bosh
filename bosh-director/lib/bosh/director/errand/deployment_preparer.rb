module Bosh::Director
  class Errand::DeploymentPreparer

    def initialize(deployment, job, event_log)
      @deployment = deployment
      @job = job
      @event_log = event_log
    end

    def prepare_deployment
      compiler = DeploymentPlan::Steps::PackageCompileStep.new(
        @deployment,
        Config.cloud,
        Config.logger,
        @event_log,
        @job
      )
      compiler.perform
    end

    def prepare_job
      @job.bind_unallocated_vms
      @job.bind_instance_networks
    end
  end
end
