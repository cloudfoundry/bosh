module Bosh::Director
  class Errand::DeploymentPreparer

    def initialize(deployment, job, event_log, base_job)
      @deployment = deployment
      @job = job
      @event_log = event_log
      @base_job = base_job
    end

    def prepare_deployment
      assembler = DeploymentPlan::Assembler.new(@deployment)

      preparer = DeploymentPlan::Steps::PrepareStep.new(@base_job, assembler)
      preparer.perform

      compiler = DeploymentPlan::Steps::PackageCompileStep.new(@deployment)
      compiler.perform
    end

    def prepare_job
      @job.bind_unallocated_vms
      @job.bind_instance_networks
    end
  end
end
