require 'spec_helper'

describe Bosh::Director::Errand::DeploymentPreparer do
  subject { described_class.new(deployment, job, event_log) }
  let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
  let(:job)        { instance_double('Bosh::Director::DeploymentPlan::Job') }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log') }

  describe '#prepare_deployment' do
    it 'binds deployment with all of its present resources' do
      cloud = double(:cloud)
      allow(Bosh::Director::Config).to receive(:cloud) { cloud }
      compiler = instance_double('Bosh::Director::DeploymentPlan::Steps::PackageCompileStep')
      expect(Bosh::Director::DeploymentPlan::Steps::PackageCompileStep).to receive(:new).
        with(deployment, cloud, logger, event_log, job).
        and_return(compiler)

      expect(compiler).to receive(:perform).with(no_args)

      subject.prepare_deployment
    end
  end

  describe '#prepare_job' do
    it 'binds unallocated vms and instance networks for given job' do
      expect(job).to receive(:bind_unallocated_vms).with(no_args)
      expect(job).to receive(:bind_instance_networks).with(no_args)

      subject.prepare_job
    end
  end
end
