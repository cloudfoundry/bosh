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

describe Bosh::Director::DeploymentPlan::ParallelMultiJobUpdater do
  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::Jobs::BaseJob') }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job', name: 'fake-job2-name') }

    let(:thread_pool) { instance_double('Bosh::Director::ThreadPool') }
    let(:logger) { Logger.new('/dev/null') }

    before { allow(Bosh::Director::ThreadPool).to receive(:new).and_return(thread_pool) }

    it 'marks a task checkpoint on the base job before running jobs in parallel' do
      expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
      expect(thread_pool).to receive(:wrap).ordered
      subject.run(base_job, deployment_plan, [])
    end

    it 'does not update jobs outside of the created thread pool' do
      allow(Bosh::Director::ThreadPool).to receive(:new).with(max_threads: 2).and_return(thread_pool)
      expect(thread_pool).to receive(:process).twice
      expect(thread_pool).to receive(:wrap).and_yield(thread_pool)

      # make sure that job updates did not happen outside of the thread pool #process
      expect(Bosh::Director::JobUpdater).to_not receive(:new)

      subject.run(base_job, deployment_plan, [job1, job2])
    end

    it 'enqueues all given jobs to run in parallel' do
      enqueued = []
      expect(thread_pool).to receive(:process).twice.and_return { |&blk| enqueued << blk }

      expect(thread_pool).to receive(:wrap).and_return do |&blk|
        blk.call(thread_pool)
        # all jobs were enqueued by the time wrap block executes
        expect(enqueued.size).to eq(2)
      end

      subject.run(base_job, deployment_plan, [job1, job2])

      # first job was enqueued
      job_updater1 = instance_double('Bosh::Director::JobUpdater', update: nil)
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job1).and_return(job_updater1)
      enqueued.first.call
      expect(job_updater1).to have_received(:update).with(no_args)

      # second job was enqueued
      job_updater2 = instance_double('Bosh::Director::JobUpdater', update: nil)
      expect(Bosh::Director::JobUpdater).to receive(:new).with(deployment_plan, job2).and_return(job_updater2)
      enqueued.last.call
      expect(job_updater2).to have_received(:update).with(no_args)
    end
  end
end
