require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::Scanner do
    let(:deployment) { FactoryBot.create(:models_deployment, :name => 'mycloud') }
    let(:scanner) { described_class.new(deployment) }

    let(:event_logger) do
      event_logger = double(:event_logger, begin_stage: nil)
      allow(event_logger).to receive(:track).and_yield(double(:ticker))
      ProblemScanner::EventLogger.new(
        event_logger,
        double(:logger, info: nil)
      )
    end

    before do
      allow(ProblemScanner::EventLogger).to receive(:new).
        and_return(event_logger)
    end

    describe 'reset' do
      it 'should mark all open problems as closed' do
        problem = Models::DeploymentProblem.make(counter: 1,
                                                 type: 'inactive_disk',
                                                 deployment: deployment,
                                                 state: 'open')

        scanner.reset

        expect(Models::DeploymentProblem.any?(&:open?)).to be(false)
        expect(Models::DeploymentProblem[problem.id].state).to eq('closed')
      end

      context 'when reseting a specific list of job instances' do
        it 'only marks the specific job instances that are open as closed' do
          instance1 = Models::Instance.make(deployment: deployment, job: 'job1', index: 0)
          instance2 = Models::Instance.make(deployment: deployment, job: 'job1', index: 1)

          problem1 = Models::DeploymentProblem.make(counter: 1,
                                                    type: 'inactive_disk',
                                                    deployment: deployment,
                                                    state: 'open',
                                                    resource_id: instance1.id)
          problem2 = Models::DeploymentProblem.make(counter: 1,
                                                    type: 'inactive_disk',
                                                    deployment: deployment,
                                                    state: 'open',
                                                    resource_id: instance2.id)
          scanner.reset([['job1', 0]])
          expect(Models::DeploymentProblem[problem1.id].state).to eq('closed')
          expect(Models::DeploymentProblem[problem2.id].state).to eq('open')
        end
      end
    end

    let(:problem_register) { instance_double('Bosh::Director::ProblemScanner::ProblemRegister') }
    before do
      allow(ProblemScanner::ProblemRegister).to receive(:new).with(deployment, logger).
        and_return(problem_register)
    end

    let(:logger) { double(:logger) }
    before { allow(Config).to receive(:logger).and_return(logger) }

    describe 'scan_vms' do
      it 'delegates to VmScanStage' do
        vms = double(:vms)

        vm_scanner = instance_double('Bosh::Director::ProblemScanner::VmScanStage')
        expect(ProblemScanner::VmScanStage).to receive(:new).with(
          instance_of(Api::InstanceManager),
          problem_register,
          deployment,
          event_logger,
          logger
        ).and_return(vm_scanner)

        expect(vm_scanner).to receive(:scan).with(vms)
        expect(vm_scanner).to receive(:agent_disks)

        scanner.scan_vms(vms)
      end
    end
    
    describe 'scan_disks' do
      it 'delegates to DiskScanStage' do
        agent_disks = double(:agent_disks)

        vm_scanner = instance_double('Bosh::Director::ProblemScanner::VmScanStage')
        allow(ProblemScanner::VmScanStage).to receive(:new).and_return(vm_scanner)
        allow(vm_scanner).to receive(:scan)
        allow(vm_scanner).to receive(:agent_disks).and_return(agent_disks)
        scanner.scan_vms

        disk_scanner = instance_double('Bosh::Director::ProblemScanner::DiskScanStage')
        expect(ProblemScanner::DiskScanStage).to receive(:new).with(
          agent_disks,
          problem_register,
          deployment.id,
          event_logger,
          logger
        ).and_return(disk_scanner)

        expect(disk_scanner).to receive(:scan)

        scanner.scan_disks
      end
    end
  end
end
