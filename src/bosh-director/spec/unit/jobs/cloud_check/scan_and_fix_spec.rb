require 'spec_helper'

module Bosh::Director
  describe Jobs::CloudCheck::ScanAndFix do
    let!(:deployment) { FactoryBot.create(:models_deployment, name: 'deployment') }
    let(:jobs) { [%w[job1 job1index0], %w[job1 job1index1], %w[job2 job2index0]] }
    let(:resolutions) do
      { Models::DeploymentProblem.all[0].id.to_s => :recreate_vm, Models::DeploymentProblem.all[1].id.to_s => :recreate_vm }
    end
    let(:fix_stateful_jobs) { true }
    let(:scan_and_fix) { described_class.new('deployment', jobs, fix_stateful_jobs) }

    before do
      instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job1', index: 0, uuid: 'job1index0')
      FactoryBot.create(:models_deployment_problem, deployment: deployment, resource_id: instance.id, type: 'unresponsive_agent')

      instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job1', index: 1, uuid: 'job1index1')
      FactoryBot.create(:models_deployment_problem, deployment: deployment, resource_id: instance.id, type: 'missing_vm')

      instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job2', index: 0, uuid: 'job2index0')
      FactoryBot.create(:models_deployment_problem, deployment: deployment, resource_id: instance.id, type: 'unbound')

      instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job2', index: 1, uuid: 'job2index1')
      FactoryBot.create(:models_deployment_problem, deployment: deployment, resource_id: instance.id, type: 'missing_vm')
      FactoryBot.create(:models_persistent_disk, instance: instance)

      instance = FactoryBot.create(:models_instance, deployment: deployment, job: 'job2', index: 2, uuid: 'job2index2', ignore: true)
      FactoryBot.create(:models_deployment_problem, deployment: deployment, resource_id: instance.id, type: 'unresponsive_agent')
    end

    describe 'DJ job class expectations' do
      let(:job_type) { :cck_scan_and_fix }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    context 'using uuid for each instance' do
      context 'when we do not want to recreate jobs with persistent disks' do
        let(:fix_stateful_jobs) { false }
        let(:jobs) { [%w[job1 job1index0], %w[job1 job1index1], %w[job2 job2index1]] }

        it 'filters out jobs with persistent disks' do
          expect(scan_and_fix.filtered_jobs).to eq([%w[job1 job1index0], %w[job1 job1index1]])
        end

        it 'should call the problem scanner with the filtered list of jobs' do
          filtered_jobs = [%w[job1 job1index0], %w[job1 job1index1]]
          resolver = instance_double('Bosh::Director::ProblemResolver').as_null_object
          expect(ProblemResolver).to receive(:new).with(deployment).and_return(resolver)
          allow(scan_and_fix).to receive(:with_deployment_lock).and_yield
          allow(resolver).to receive(:apply_resolutions).and_return(0)
          allow(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection)

          scanner = instance_double('Bosh::Director::ProblemScanner::Scanner')
          expect(ProblemScanner::Scanner).to receive(:new).and_return(scanner)
          expect(scanner).to receive(:reset).with(filtered_jobs)
          expect(scanner).to receive(:scan_vms).with(filtered_jobs)

          scan_and_fix.perform
        end
      end

      context 'when we want to recreate jobs with persistent disks' do
        it 'filters out nothing' do
          expect(scan_and_fix.filtered_jobs).to eq(jobs)
        end

        it 'should call the problem scanner with all of the jobs' do
          resolver = instance_double('Bosh::Director::ProblemResolver').as_null_object
          expect(ProblemResolver).to receive(:new).with(deployment).and_return(resolver)
          allow(scan_and_fix).to receive(:with_deployment_lock).and_yield
          allow(resolver).to receive(:apply_resolutions).and_return(1)
          allow(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection)

          scanner = instance_double('Bosh::Director::ProblemScanner::Scanner')
          expect(ProblemScanner::Scanner).to receive(:new).and_return(scanner)
          expect(scanner).to receive(:reset).with(jobs)
          expect(scanner).to receive(:scan_vms).with(jobs)

          scan_and_fix.perform
        end
      end

      it 'should call the problem resolver' do
        scanner = instance_double('Bosh::Director::ProblemScanner::Scanner').as_null_object
        allow(ProblemScanner::Scanner).to receive_messages(new: scanner)
        allow(scan_and_fix).to receive(:with_deployment_lock).and_yield
        allow(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection)

        resolver = instance_double('Bosh::Director::ProblemResolver')
        expect(ProblemResolver).to receive(:new).and_return(resolver)
        expect(resolver).to receive(:apply_resolutions).with(resolutions).and_return(0)

        scan_and_fix.perform
      end

      it 'should call the post_deploy script runner' do
        scanner = instance_double('Bosh::Director::ProblemScanner::Scanner').as_null_object
        allow(ProblemScanner::Scanner).to receive_messages(new: scanner)
        allow(scan_and_fix).to receive(:with_deployment_lock).and_yield

        resolver = instance_double('Bosh::Director::ProblemResolver')
        allow(ProblemResolver).to receive(:new).and_return(resolver)
        allow(resolver).to receive(:apply_resolutions).with(resolutions).and_return(1)

        expect(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection).with(deployment)

        scan_and_fix.perform
      end

      it 'should create a list of resolutions' do
        expect(scan_and_fix.resolutions(jobs)).to eq(resolutions)
      end
    end

    context 'an error occurs' do
      before do
        scanner = instance_double('Bosh::Director::ProblemScanner::Scanner').as_null_object
        allow(ProblemScanner::Scanner).to receive_messages(new: scanner)
        allow(scan_and_fix).to receive(:with_deployment_lock).and_yield
      end

      it 'should give a nice message for Lock::TimeoutError' do
        resolver = instance_double('Bosh::Director::ProblemResolver')
        allow(ProblemResolver).to receive(:new).and_return(resolver)
        allow(resolver).to receive(:apply_resolutions).and_raise(Lock::TimeoutError, 'this original error message will change')

        expect { scan_and_fix.perform }.to raise_error(
          RuntimeError,
          /Unable to get deployment lock, maybe a deployment is in progress. Try again later./,
        )
        expect(PostDeploymentScriptRunner).to_not receive(:run_post_deploys_after_resurrection)
      end

      it 'should pass on other exceptions' do
        error = RuntimeError.new('This is not supposed to happen')
        resolver = instance_double('Bosh::Director::ProblemResolver')
        allow(ProblemResolver).to receive(:new).and_return(resolver)
        allow(resolver).to receive(:apply_resolutions).and_raise(error)

        expect { scan_and_fix.perform }.to raise_error(error)
        expect(PostDeploymentScriptRunner).to_not receive(:run_post_deploys_after_resurrection)
      end
    end

    describe '#perform' do
      context 'when problem resolution fails' do
        it 'raises an error' do
          scanner = instance_double('Bosh::Director::ProblemScanner::Scanner').as_null_object
          allow(ProblemScanner::Scanner).to receive_messages(new: scanner)
          allow(scan_and_fix).to receive(:with_deployment_lock).and_yield

          resolver = instance_double('Bosh::Director::ProblemResolver')
          expect(ProblemResolver).to receive(:new).and_return(resolver)
          expect(resolver).to receive(:apply_resolutions).and_return([1, 'error message'])
          expect(PostDeploymentScriptRunner).to receive(:run_post_deploys_after_resurrection)

          expect do
            scan_and_fix.perform
          end.to raise_error(Bosh::Director::ProblemHandlerError)
        end
      end
    end

    describe '#resolutions' do
      it 'only lists resolutions for jobs whose state is either "unresponsive_agent" or "missing_vm"' do
        res = scan_and_fix.resolutions(jobs)
        expect(res).to eq(resolutions)
      end

      context 'when a VM is ignored' do
        let(:jobs) { [%w[job1 job1index0], %w[job2 job2index2]] }

        it 'should not list it as a resolution' do
          res = scan_and_fix.resolutions(jobs)
          expect(res).to eq(Models::DeploymentProblem.all[0].id.to_s => :recreate_vm)
        end
      end
    end
  end
end
