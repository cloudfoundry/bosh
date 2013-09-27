require 'spec_helper'

module Bosh::Director
  describe Jobs::CloudCheck::ScanAndFix do
    before do
      deployment = Models::Deployment.make(name: 'deployment')

      instance = Models::Instance.make(deployment: deployment, job: 'job1', index: 0)
      Models::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unresponsive_agent')

      instance = Models::Instance.make(deployment: deployment, job: 'job1', index: 1)
      Models::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')

      instance = Models::Instance.make(deployment: deployment, job: 'job2', index: 0)
      Models::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'unbound')

      instance = Models::Instance.make(deployment: deployment, job: 'job2', index: 1)
      Models::DeploymentProblem.make(deployment: deployment, resource_id: instance.id, type: 'missing_vm')
      Models::PersistentDisk.make(instance: instance)
    end

    let(:deployment) { Models::Deployment[1] }
    let(:jobs) { [['job1', 0], ['job1', 1], ['job2', 0]] }
    let(:resolutions) { {'1' => :recreate_vm, '2' => :recreate_vm} }
    let(:fix_stateful_jobs) { true }
    let(:scan_and_fix) { described_class.new('deployment', jobs, fix_stateful_jobs) }

    describe 'Resque job class expectations' do
      let(:job_type) { :cck_scan_and_fix }
      it_behaves_like 'a Resque job'
    end

    context 'when we do not want to recreate jobs with persistent disks' do
      let(:fix_stateful_jobs) { false }
      let(:jobs) { [['job1', 0], ['job1', 1], ['job2', 1]] }

      it 'filters out jobs with persistent disks' do
        scan_and_fix.filtered_jobs.should == [['job1', 0], ['job1', 1]]
      end

      it 'should call the problem scanner with the filtered list of jobs' do
        filtered_jobs = [['job1', 0], ['job1', 1]]
        resolver = instance_double('Bosh::Director::ProblemResolver').as_null_object
        ProblemResolver.should_receive(:new).with(deployment).and_return(resolver)
        scan_and_fix.stub(:with_deployment_lock).and_yield

        scanner = instance_double('Bosh::Director::ProblemScanner')
        ProblemScanner.should_receive(:new).and_return(scanner)
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
        resolver = instance_double('Bosh::Director::ProblemResolver').as_null_object
        ProblemResolver.should_receive(:new).with(deployment).and_return(resolver)
        scan_and_fix.stub(:with_deployment_lock).and_yield

        scanner = instance_double('Bosh::Director::ProblemScanner')
        ProblemScanner.should_receive(:new).and_return(scanner)
        scanner.should_receive(:reset).with(jobs)
        scanner.should_receive(:scan_vms).with(jobs)

        scan_and_fix.perform
      end
    end

    it 'should call the problem resolver' do
      scanner = instance_double('Bosh::Director::ProblemScanner').as_null_object
      ProblemScanner.stub(new: scanner)
      scan_and_fix.stub(:with_deployment_lock).and_yield

      resolver = instance_double('Bosh::Director::ProblemResolver')
      ProblemResolver.should_receive(:new).and_return(resolver)
      resolver.should_receive(:apply_resolutions).with(resolutions)

      scan_and_fix.perform
    end

    it 'should create a list of resolutions' do
      scan_and_fix.resolutions(jobs).should == resolutions
    end

    it 'should not recreate vms with resurrection_paused turned on' do
      unresponsive_instance = Models::Instance.find(deployment: deployment, job: 'job1', index: 0)
      unresponsive_instance.resurrection_paused = true
      unresponsive_instance.save

      missing_vm_instance = Models::Instance.find(deployment: deployment, job: 'job1', index: 1)
      missing_vm_instance.resurrection_paused = true
      missing_vm_instance.save

      scan_and_fix.resolutions(jobs).should be_empty
    end
  end
end
