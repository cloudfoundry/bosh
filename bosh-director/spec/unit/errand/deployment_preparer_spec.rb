require 'spec_helper'

describe Bosh::Director::Errand::DeploymentPreparer do
  subject { described_class.new(deployment, job, event_log, base_job) }
  let(:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }
  let(:job)        { instance_double('Bosh::Director::DeploymentPlan::Job') }
  let(:event_log)  { instance_double('Bosh::Director::EventLog::Log') }
  let(:base_job)   { instance_double('Bosh::Director::Jobs::BaseJob') }

  describe '#prepare_deployment' do
    it 'binds deployment with all of its present resources' do
      assembler = instance_double('Bosh::Director::DeploymentPlan::Assembler')
      expect(Bosh::Director::DeploymentPlan::Assembler).to receive(:new).
        with(deployment).
        and_return(assembler)

      preparer = instance_double('Bosh::Director::DeploymentPlan::Preparer')
      expect(Bosh::Director::DeploymentPlan::Preparer).to receive(:new).
        with(base_job, assembler).
        and_return(preparer)

      expect(preparer).to receive(:prepare).with(no_args)

      compiler = instance_double('Bosh::Director::PackageCompiler')
      expect(Bosh::Director::PackageCompiler).to receive(:new).
        with(deployment).
        and_return(compiler)

      expect(compiler).to receive(:compile).with(no_args)

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
