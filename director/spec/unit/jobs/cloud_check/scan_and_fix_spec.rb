require 'spec_helper'

describe Bosh::Director::Jobs::CloudCheck::ScanAndFix do
  before do
    deployment = BDM::Deployment.make(name: 'deployment')

    instance = BDM::Instance.make(deployment: deployment, job: 'job1', index: 0)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unresponsive_agent')

    instance = BDM::Instance.make(deployment: deployment, job: 'job1', index: 1)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')

    instance = BDM::Instance.make(deployment: deployment, job: 'job2', index: 0)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unbound')

    instance = BDM::Instance.make(deployment: deployment, job: 'job2', index: 1)
    BDM::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')
    BDM::PersistentDisk.make(instance: instance)
  end

  let(:deployment) { BDM::Deployment[1] }
  let(:jobs) { [['job1', 0], ['job1', 1], ['job2', 0]] }
  let(:resolutions) { {'1' => :recreate_vm, '2' => :recreate_vm} }
  let(:fix_stateful_jobs) { true }
  let(:scan_and_fix) { described_class.new('deployment', jobs, fix_stateful_jobs) }

  describe 'described_class.job_type' do
    it 'returns a symbol representing job type' do
      expect(described_class.job_type).to eq(:cck_scan_and_fix)
    end
  end

  context 'when we do not want to recreate jobs with persistent disks' do
    let(:fix_stateful_jobs) { false }
    let(:jobs) { [['job1', 0], ['job1', 1], ['job2', 1]] }

    it 'filters out jobs with persistent disks' do
      scan_and_fix.filtered_jobs.should == [['job1', 0], ['job1', 1]]
    end

    it 'should call the problem scanner with the filtered list of jobs' do
      filtered_jobs = [['job1', 0], ['job1', 1]]
      resolver = double(BD::ProblemResolver).as_null_object
      BD::ProblemResolver.should_receive(:new).with(deployment).and_return(resolver)
      scan_and_fix.stub(:with_deployment_lock).and_yield

      scanner = double(BD::ProblemScanner)
      BD::ProblemScanner.should_receive(:new).and_return(scanner)
      scanner.should_receive(:reset).with(filtered_jobs)
      scanner.should_receive(:scan_vms).with(filtered_jobs)

      scan_and_fix.perform
    end
  end

  context 'when we want to recreate jobs with persistent disks' do
    let(:fix_stateful_jobs) { true }

    it 'filters out nothing' do
      scan_and_fix.filtered_jobs.should == jobs
    end

    it 'should call the problem scanner with all of the jobs' do
      resolver = double(BD::ProblemResolver).as_null_object
      BD::ProblemResolver.should_receive(:new).with(deployment).and_return(resolver)
      scan_and_fix.stub(:with_deployment_lock).and_yield

      scanner = double(BD::ProblemScanner)
      BD::ProblemScanner.should_receive(:new).and_return(scanner)
      scanner.should_receive(:reset).with(jobs)
      scanner.should_receive(:scan_vms).with(jobs)

      scan_and_fix.perform
    end
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
    scan_and_fix.resolutions(jobs).should == resolutions
  end

  it 'should not recreate vms with resurrection_paused turned on' do
    unresponsive_instance = BDM::Instance.find(deployment: deployment, job: 'job1', index: 0)
    unresponsive_instance.resurrection_paused = true
    unresponsive_instance.save

    missing_vm_instance = BDM::Instance.find(deployment: deployment, job: 'job1', index: 1)
    missing_vm_instance.resurrection_paused = true
    missing_vm_instance.save

    scan_and_fix.resolutions(jobs).should be_empty
  end

end
