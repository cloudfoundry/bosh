require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

describe Bosh::Director::DeploymentPlan::SerialMultiJobUpdater do
  subject { described_class.new(job_updater_factory) }
  let(:job_updater_factory) { instance_double('Bosh::Director::JobUpdaterFactory') }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::Jobs::BaseJob') }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job2-name') }

    context 'with 1+ jobs' do
      it 'updates each job serially' do
        job_updater1 = instance_double('Bosh::Director::JobUpdater')
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job1).and_return(job_updater1)
        expect(job_updater1).to receive(:update).with(no_args).ordered

        job_updater2 = instance_double('Bosh::Director::JobUpdater')
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job2).and_return(job_updater2)
        expect(job_updater2).to receive(:update).with(no_args).ordered

        subject.run(base_job, deployment_plan, [job1, job2])
      end

      it 'task checkpoints before updating each job' do
        expect(base_job).to receive(:task_checkpoint).ordered

        job_updater1 = instance_double('Bosh::Director::JobUpdater')
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job1).and_return(job_updater1)
        expect(job_updater1).to receive(:update).with(no_args).ordered

        expect(base_job).to receive(:task_checkpoint).ordered

        job_updater2 = instance_double('Bosh::Director::JobUpdater')
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job2).and_return(job_updater2)
        expect(job_updater2).to receive(:update).with(no_args).ordered

        subject.run(base_job, deployment_plan, [job1, job2])
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        subject.run(base_job, deployment_plan, [])
      end
    end
  end
end

describe Bosh::Director::DeploymentPlan::ParallelMultiJobUpdater do
  subject { described_class.new(job_updater_factory) }
  let(:job_updater_factory) { instance_double('Bosh::Director::JobUpdaterFactory') }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::Jobs::BaseJob') }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job2-name') }

    let(:thread_pool) { instance_double('Bosh::Director::ThreadPool') }

    before { allow(Bosh::Director::ThreadPool).to receive(:new).and_return(thread_pool) }

    context 'with 1+ jobs' do
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
        expect(job_updater_factory).to_not receive(:new_job_updater)

        subject.run(base_job, deployment_plan, [job1, job2])
      end

      it 'enqueues all given jobs to run in parallel' do
        enqueued = []
        expect(thread_pool).to receive(:process).twice { |&blk| enqueued << blk }

        expect(thread_pool).to receive(:wrap) do |&blk|
          blk.call(thread_pool)
          # all jobs were enqueued by the time wrap block executes
          expect(enqueued.size).to eq(2)
        end

        subject.run(base_job, deployment_plan, [job1, job2])

        # first job was enqueued
        job_updater1 = instance_double('Bosh::Director::JobUpdater', update: nil)
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job1).and_return(job_updater1)
        enqueued.first.call
        expect(job_updater1).to have_received(:update).with(no_args)

        # second job was enqueued
        job_updater2 = instance_double('Bosh::Director::JobUpdater', update: nil)
        expect(job_updater_factory).to receive(:new_job_updater).with(deployment_plan, job2).and_return(job_updater2)
        enqueued.last.call
        expect(job_updater2).to have_received(:update).with(no_args)
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        allow(thread_pool).to receive(:wrap).ordered
        subject.run(base_job, deployment_plan, [])
      end
    end
  end
end

describe Bosh::Director::DeploymentPlan::BatchMultiJobUpdater do
  subject { described_class.new(job_updater_factory) }
  let(:job_updater_factory) { instance_double('Bosh::Director::JobUpdaterFactory') }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::Jobs::BaseJob') }

    before do
      allow(Bosh::Director::DeploymentPlan::SerialMultiJobUpdater).to receive(:new).
        with(job_updater_factory).
        and_return(serial_updater)
    end
    let(:serial_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater') }

    let(:serial_job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-serial-job1-name', update: serial_update_config) }
    let(:serial_job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-serial-job2-name', update: serial_update_config) }
    let(:serial_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: true) }

    before do
      allow(Bosh::Director::DeploymentPlan::ParallelMultiJobUpdater).to receive(:new).
        with(job_updater_factory).
        and_return(parallel_updater)
    end
    let(:parallel_updater) { instance_double('Bosh::Director::DeploymentPlan::ParallelMultiJobUpdater') }

    let(:parallel_job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-parallel-job1-name', update: parallel_update_config) }
    let(:parallel_job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-parallel-job2-name', update: parallel_update_config) }
    let(:parallel_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: false) }

    context 'when all jobs need to run serially' do
      it 'runs them all serially' do
        jobs = [serial_job1, serial_job2]
        expect(serial_updater).to receive(:run).with(base_job, deployment_plan, jobs)
        subject.run(base_job, deployment_plan, jobs)
      end
    end

    context 'when all jobs need to run in parallel' do
      it 'runs them all in parallel' do
        jobs = [parallel_job1, parallel_job2]
        expect(parallel_updater).to receive(:run).with(base_job, deployment_plan, jobs)
        subject.run(base_job, deployment_plan, jobs)
      end
    end

    context 'when jobs need to run serially, in parallel and then serially again' do
      it 'runs jobs with parallel and serial updaters' do
        jobs = [serial_job1, parallel_job1, parallel_job2, serial_job2]
        expect(serial_updater).to receive(:run).with(base_job, deployment_plan, [serial_job1]).ordered
        expect(parallel_updater).to receive(:run).with(base_job, deployment_plan, [parallel_job1, parallel_job2]).ordered
        expect(serial_updater).to receive(:run).with(base_job, deployment_plan, [serial_job2]).ordered
        subject.run(base_job, deployment_plan, jobs)
      end
    end

    context 'when jobs need to run in parallel, serially and then in parallel again' do
      it 'runs jobs with parallel and serial updaters' do
        jobs = [parallel_job1, serial_job1, serial_job2, parallel_job2]
        expect(parallel_updater).to receive(:run).with(base_job, deployment_plan, [parallel_job1]).ordered
        expect(serial_updater).to receive(:run).with(base_job, deployment_plan, [serial_job1, serial_job2]).ordered
        expect(parallel_updater).to receive(:run).with(base_job, deployment_plan, [parallel_job2]).ordered
        subject.run(base_job, deployment_plan, jobs)
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        subject.run(base_job, deployment_plan, [])
      end
    end
  end
end
