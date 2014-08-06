require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::DiskScanStage do
    subject(:disk_scanner) do
      described_class.new(
        disk_owners,
        problem_register,
        cloud,
        deployment.id,
        event_logger,
        double(:logger, info: nil, warn: nil)
      )
    end

    let(:disk_owners) { {} }
    let(:problem_register) { instance_double('Bosh::Director::ProblemScanner::ProblemRegister') }
    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:deployment) { Models::Deployment.make(name: 'fake-deployment') }
    let(:event_logger) { double(:event_logger, begin_stage: nil) }
    before do
      allow(event_logger).to receive(:track_and_log) do |_, &blk|
        blk.call if blk
      end
    end

    describe '#scan' do
      let(:disk_state) { true }

      let!(:disk) do
        Models::PersistentDisk.make(active: disk_state, instance_id: instance.id, disk_cid: 'fake-disk-cid')
      end
      let!(:instance) { Models::Instance.make(deployment: deployment, job: 'fake-job', index: 0, vm: vm) }
      let!(:vm) { Models::Vm.make(cid: 'fake-vm-cid', agent_id: 'fake-agent-id', deployment: deployment) }
      let(:disk_owners) { {'fake-disk-cid' => ['fake-vm-cid']} }
      before { allow(cloud).to receive(:has_disk?).and_return(true) }

      context 'when cloud does not have disk' do
        before { allow(cloud).to receive(:has_disk?).and_return(false) }

        it 'registers missing disk problem' do
          expect(problem_register).to receive(:problem_found).with(:missing_disk, disk)
          expect(event_logger).to receive(:track_and_log).with('0 OK, 1 missing, 0 inactive, 0 mount-info mismatch')
          disk_scanner.scan
        end
      end

      context 'when cloud does not implement has_disk?' do
        before do
          allow(cloud).to receive(:has_disk?).and_raise(Bosh::Clouds::NotImplemented)
        end

        it 'does not register any problems' do
          expect(problem_register).to_not receive(:problem_found)
          disk_scanner.scan
        end
      end

      context 'when disk is inactive' do
        let(:disk_state) { false }

        it 'registers inactive disk problem' do
          expect(problem_register).to receive(:problem_found).with(:inactive_disk, disk)
          expect(event_logger).to receive(:track_and_log).with('0 OK, 0 missing, 1 inactive, 0 mount-info mismatch')
          disk_scanner.scan
        end
      end

      context 'when disk is not associated with VM' do
        let(:vm) { nil }

        it 'reports no problems' do
          expect(problem_register).to_not receive(:problem_found)
          disk_scanner.scan
        end
      end

      context 'when disk is attached do different VM' do
        let(:disk_owners) { { disk.disk_cid => owner_vms } }
        let(:owner_vms) { ['different-vm-cid'] }

        it 'registers disk mount problem' do
          expect(problem_register).to receive(:problem_found).
            with(:mount_info_mismatch, disk, owner_vms: owner_vms)
          disk_scanner.scan
        end
      end
    end
  end
end
