require 'spec_helper'
require 'bosh/director/deployment_plan/multi_instance_group_updater'
require 'bosh/director/instance_group_updater'

describe Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater do
  subject { described_class.new(instance_group_updater_factory) }
  let(:instance_group_updater_factory) { instance_double('Bosh::Director::InstanceGroupUpdaterFactory') }
  let(:ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider) }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job2-name') }

    context 'with 1+ jobs' do
      it 'updates each job serially' do
        instance_group_updater1 = instance_double('Bosh::Director::InstanceGroupUpdater')
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job1).and_return(instance_group_updater1)
        expect(instance_group_updater1).to receive(:update).with(no_args).ordered

        instance_group_updater2 = instance_double('Bosh::Director::InstanceGroupUpdater')
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job2).and_return(instance_group_updater2)
        expect(instance_group_updater2).to receive(:update).with(no_args).ordered

        subject.run(base_job, ip_provider, [job1, job2])
      end

      it 'task checkpoints before updating each job' do
        expect(base_job).to receive(:task_checkpoint).ordered

        instance_group_updater1 = instance_double('Bosh::Director::InstanceGroupUpdater')
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job1).and_return(instance_group_updater1)
        expect(instance_group_updater1).to receive(:update).with(no_args).ordered

        expect(base_job).to receive(:task_checkpoint).ordered

        instance_group_updater2 = instance_double('Bosh::Director::InstanceGroupUpdater')
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job2).and_return(instance_group_updater2)
        expect(instance_group_updater2).to receive(:update).with(no_args).ordered

        subject.run(base_job, ip_provider, [job1, job2])
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        subject.run(base_job, ip_provider, [])
      end
    end
  end
end

describe Bosh::Director::DeploymentPlan::ParallelMultiInstanceGroupUpdater do
  subject { described_class.new(instance_group_updater_factory) }
  let(:ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider) }
  let(:instance_group_updater_factory) { instance_double('Bosh::Director::InstanceGroupUpdaterFactory') }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }
    let(:job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job1-name') }
    let(:job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-job2-name') }

    let(:thread_pool) { instance_double('Bosh::Director::ThreadPool') }

    before { allow(Bosh::Director::ThreadPool).to receive(:new).and_return(thread_pool) }

    context 'with 1+ jobs' do
      it 'marks a task checkpoint on the base job before running jobs in parallel' do
        expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
        expect(thread_pool).to receive(:wrap).ordered
        subject.run(base_job, ip_provider, [])
      end

      it 'does not update jobs outside of the created thread pool' do
        allow(Bosh::Director::ThreadPool).to receive(:new).with(max_threads: 2).and_return(thread_pool)
        expect(thread_pool).to receive(:process).twice
        expect(thread_pool).to receive(:wrap).and_yield(thread_pool)

        # make sure that job updates did not happen outside of the thread pool #process
        expect(instance_group_updater_factory).to_not receive(:new_instance_group_updater)

        subject.run(base_job, ip_provider, [job1, job2])
      end

      it 'enqueues all given jobs to run in parallel' do
        enqueued = []
        expect(thread_pool).to receive(:process).twice { |&blk| enqueued << blk }

        expect(thread_pool).to receive(:wrap) do |&blk|
          blk.call(thread_pool)
          # all jobs were enqueued by the time wrap block executes
          expect(enqueued.size).to eq(2)
        end

        subject.run(base_job, ip_provider, [job1, job2])

        # first job was enqueued
        instance_group_updater1 = instance_double('Bosh::Director::InstanceGroupUpdater', update: nil)
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job1).and_return(instance_group_updater1)
        enqueued.first.call
        expect(instance_group_updater1).to have_received(:update).with(no_args)

        # second job was enqueued
        instance_group_updater2 = instance_double('Bosh::Director::InstanceGroupUpdater', update: nil)
        expect(instance_group_updater_factory).to receive(:new_instance_group_updater).with(ip_provider, job2).and_return(instance_group_updater2)
        enqueued.last.call
        expect(instance_group_updater2).to have_received(:update).with(no_args)
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        allow(thread_pool).to receive(:wrap)
        subject.run(base_job, ip_provider, [])
      end
    end
  end
end

describe Bosh::Director::DeploymentPlan::BatchMultiInstanceGroupUpdater do
  subject { described_class.new(instance_group_updater_factory) }
  let(:ip_provider) { instance_double(Bosh::Director::DeploymentPlan::IpProvider) }
  let(:instance_group_updater_factory) { instance_double('Bosh::Director::InstanceGroupUpdaterFactory') }

  describe '#run' do
    let(:base_job) { instance_double('Bosh::Director::Jobs::BaseJob', task_checkpoint: nil, logger: logger) }

    before do
      allow(Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater).to receive(:new).
        with(instance_group_updater_factory).
        and_return(serial_updater)
    end
    let(:serial_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiInstanceGroupUpdater') }

    let(:serial_job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-serial-job1-name', update: serial_update_config) }
    let(:serial_job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-serial-job2-name', update: serial_update_config) }
    let(:serial_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: true) }

    before do
      allow(Bosh::Director::DeploymentPlan::ParallelMultiInstanceGroupUpdater).to receive(:new).
        with(instance_group_updater_factory).
        and_return(parallel_updater)
    end
    let(:parallel_updater) { instance_double('Bosh::Director::DeploymentPlan::ParallelMultiInstanceGroupUpdater') }

    let(:parallel_job1) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-parallel-job1-name', update: parallel_update_config) }
    let(:parallel_job2) { instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'fake-parallel-job2-name', update: parallel_update_config) }
    let(:parallel_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: false) }

    context 'when all jobs need to run serially' do
      it 'runs them all serially' do
        jobs = [serial_job1, serial_job2]
        expect(serial_updater).to receive(:run).with(base_job, ip_provider, jobs)
        subject.run(base_job, ip_provider, jobs)
      end
    end

    context 'when all jobs need to run in parallel' do
      it 'runs them all in parallel' do
        jobs = [parallel_job1, parallel_job2]
        expect(parallel_updater).to receive(:run).with(base_job, ip_provider, jobs)
        subject.run(base_job, ip_provider, jobs)
      end
    end

    context 'when jobs need to run serially, in parallel and then serially again' do
      it 'runs jobs with parallel and serial updaters' do
        jobs = [serial_job1, parallel_job1, parallel_job2, serial_job2]
        expect(serial_updater).to receive(:run).with(base_job, ip_provider, [serial_job1]).ordered
        expect(parallel_updater).to receive(:run).with(base_job, ip_provider, [parallel_job1, parallel_job2]).ordered
        expect(serial_updater).to receive(:run).with(base_job, ip_provider, [serial_job2]).ordered
        subject.run(base_job, ip_provider, jobs)
      end
    end

    context 'when jobs need to run in parallel, serially and then in parallel again' do
      it 'runs jobs with parallel and serial updaters' do
        jobs = [parallel_job1, serial_job1, serial_job2, parallel_job2]
        expect(parallel_updater).to receive(:run).with(base_job, ip_provider, [parallel_job1]).ordered
        expect(serial_updater).to receive(:run).with(base_job, ip_provider, [serial_job1, serial_job2]).ordered
        expect(parallel_updater).to receive(:run).with(base_job, ip_provider, [parallel_job2]).ordered
        subject.run(base_job, ip_provider, jobs)
      end
    end

    context 'when there are 0 jobs' do
      it 'runs nothing' do
        subject.run(base_job, ip_provider, [])
      end
    end
  end
end
