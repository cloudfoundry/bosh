require 'spec_helper'

describe Bosh::Director::Jobs::CloudCheck::ScanAndFix do
  before do
    deployment = BDM::Deployment.make(name: 'deployment')

    instance = BDM::Instance.make(deployment: deployment, job: 'j1', index: 0)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unresponsive_agent')

    instance = BDM::Instance.make(deployment: deployment, job: 'j1', index: 1)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')

    instance = BDM::Instance.make(deployment: deployment, job: 'j2', index: 0)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unbound')

    instance = BDM::Instance.make(deployment: deployment, job: 'j2', index: 1)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')
    BDM::PersistentDisk.make(instance: instance)
  end

  let(:deployment) { BDM::Deployment[1] }
  let(:jobs) { {'j1' => [0, 1], 'j2' => [0]} }
  let(:filtered_jobs) { {'j1' => [0, 1], 'j2' => [0]} }
  let(:resolutions) { {'1' => :recreate_vm, '2' => :recreate_vm} }
  let(:scan_and_fix) { described_class.new('deployment', jobs) }

  it 'should call the problem scanner' do
    resolver = double(BD::ProblemResolver).as_null_object
    BD::ProblemResolver.should_receive(:new).with(deployment).and_return(resolver)
    scan_and_fix.stub(:with_deployment_lock).and_yield

    scanner = double(BD::ProblemScanner)
    BD::ProblemScanner.should_receive(:new).and_return(scanner)
    scanner.should_receive(:reset).with(filtered_jobs)
    scanner.should_receive(:scan_vms).with(filtered_jobs)

    scan_and_fix.perform
  end

  it 'should call the problem resolver' do
    scanner = double(BD::ProblemScanner).as_null_object
    BD::ProblemScanner.stub(new: scanner)
    scan_and_fix.stub(:with_deployment_lock).and_yield

    resolver = double(BD::ProblemResolver)
    BD::ProblemResolver.should_receive(:new).and_return(resolver)
    resolver.should_receive(:apply_resolutions).with(resolutions)

    scan_and_fix.perform
  end

  it 'should create a list of resolutions' do
    scan_and_fix.filter_out_jobs_with_persistent_disks

    scan_and_fix.resolutions.should == resolutions
  end

  describe '#filter_out_jobs_with_persistent_disks' do
    let(:jobs) {
      { 'j1' => [0, 1], 'j2' => [1] }
    }

    it 'should filter out jobs with persistent disks' do
      scan_and_fix.filter_out_jobs_with_persistent_disks
      scan_and_fix.filtered_jobs.should == {'j1' => [0, 1], 'j2' => []}
    end
  end
end
