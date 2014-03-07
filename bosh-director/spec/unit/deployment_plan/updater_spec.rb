require 'spec_helper'
require 'bosh/director/deployment_plan/multi_job_updater'
require 'bosh/director/job_updater'

describe Bosh::Director::DeploymentPlan::Updater do
  subject { described_class.new(base_job, event_log, resource_pools, assembler, deployment_plan, multi_job_updater) }
  let(:base_job)        { instance_double('Bosh::Director::Jobs::BaseJob') }
  let(:event_log)       { instance_double('Bosh::Director::EventLog::Log', begin_stage: nil) }
  let(:resource_pools)  { instance_double('Bosh::Director::DeploymentPlan::ResourcePools') }
  let(:assembler)       { instance_double('Bosh::Director::DeploymentPlan::Assembler') }
  let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', jobs_starting_on_deploy: jobs) }
  let(:jobs)            { instance_double('Array') }
  let(:multi_job_updater) { instance_double('Bosh::Director::DeploymentPlan::SerialMultiJobUpdater') }

  before { allow(base_job).to receive(:logger).and_return(Logger.new('/dev/null')) }
  before { allow(base_job).to receive(:track_and_log).and_yield }
  before { allow(Bosh::Director::Config).to receive(:dns_enabled?).and_return(true) }

  describe '#update' do
    it 'runs deployment plan update stages in a specific order' do
      expect(assembler).to receive(:bind_dns).with(no_args).ordered
      expect(resource_pools).to receive(:update).with(no_args).ordered
      expect(base_job).to receive(:task_checkpoint).with(no_args).ordered
      expect(assembler).to receive(:bind_instance_vms).with(no_args).ordered
      expect(assembler).to receive(:bind_configuration).with(no_args).ordered
      expect(assembler).to receive(:delete_unneeded_vms).with(no_args).ordered
      expect(assembler).to receive(:delete_unneeded_instances).with(no_args).ordered
      expect(multi_job_updater).to receive(:run).with(base_job, deployment_plan, jobs).ordered
      expect(resource_pools).to receive(:refill).with(no_args).ordered
      subject.update
    end
  end
end
