module Bosh::Director
  class Errand::DeploymentPreparer
    # @param [Bosh::Director::DeploymentPlan::Planner] deployment
    # @param [Bosh::Director::DeploymentPlan::Job] job
    # @param [Bosh::Director::EventLog::Log] event_log
    # @param [Bosh::Blobstore::Jobs::BaseJob] base_job
    def initialize(deployment, job, event_log, base_job)
      @deployment = deployment
      @job = job
      @event_log = event_log
      @base_job = base_job
    end

    def prepare_deployment
      assembler = DeploymentPlan::Assembler.new(@deployment)

      preparer = DeploymentPlan::Preparer.new(@base_job, assembler)
      preparer.prepare

      compiler = PackageCompiler.new(@deployment)
      compiler.compile
    end

    def prepare_job
      @job.bind_unallocated_vms
      @job.bind_instance_networks
    end
  end
end
