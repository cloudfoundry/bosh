require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

describe Bosh::Director::DeploymentPlan::SerialMultiJobUpdater do
  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::Jobs::BaseJob') }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job2-name') }

    let(:logger) { Logger.new('/dev/null') }

    it 'updates each job serially' do
      job_updater1 = instance_double('Bosh::Director::JobUpdater')
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job1).and_return(job_updater1)
      expect(job_updater1).to receive(:update).with(no_args).ordered

      job_updater2 = instance_double('Bosh::Director::JobUpdater')
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job2).and_return(job_updater2)
      expect(job_updater2).to receive(:update).with(no_args).ordered

      subject.run(base_job, deployment_plan, [job1, job2])
    end

    it 'task checkpoints before updating each job' do
      expect(base_job).to receive(:task_checkpoint).ordered

      job_updater1 = instance_double('Bosh::Director::JobUpdater')
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job1).and_return(job_updater1)
      expect(job_updater1).to receive(:update).with(no_args).ordered

      expect(base_job).to receive(:task_checkpoint).ordered

      job_updater2 = instance_double('Bosh::Director::JobUpdater')
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job2).and_return(job_updater2)
      expect(job_updater2).to receive(:update).with(no_args).ordered

      subject.run(base_job, deployment_plan, [job1, job2])
    end
  end
end
