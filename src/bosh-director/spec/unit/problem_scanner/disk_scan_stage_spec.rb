require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::DiskScanStage do
    subject(:disk_scanner) do
      described_class.new(
        disk_owners,
        problem_register,
        deployment.id,
        event_logger,
        double(:logger, info: nil, warn: nil)
      )
    end

    let(:disk_owners) do
      {}
    end
    let(:problem_register) { instance_double('Bosh::Director::ProblemScanner::ProblemRegister') }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(Bosh::Director::AZCloudFactory) }
    let(:deployment) { FactoryBot.create(:models_deployment, name: 'fake-deployment') }
    let(:event_logger) { double(:event_logger, begin_stage: nil) }
    let(:thread_pool) { double(ThreadPool) }
    let(:thread_limit) { double(5) }
    let(:disk_count) { 1 }

    before do
      expect(thread_pool).to receive(:wrap)  do |&blk|
        blk.call(thread_pool) if blk
      end

      expect(thread_pool).to receive(:process).exactly(disk_count).times.and_yield
      allow(Config).to receive(:max_threads).and_return thread_limit
      expect(ThreadPool).to receive(:new).with(max_threads: thread_limit).and_return(thread_pool)

      allow(event_logger).to receive(:track_and_log) do |_, &blk|
        blk.call if blk
      end
      allow(Bosh::Director::AZCloudFactory).to receive(:create_with_latest_configs).and_return(cloud_factory)
    end

    describe '#scan' do
      let(:disk_state) { true }

      let!(:disk) do
        Models::PersistentDisk.make(active: disk_state, instance_id: instance.id, disk_cid: 'fake-disk-cid')
      end
      let!(:vm) { Models::Vm.make(cid: 'fake-vm-cid', instance_id: instance.id) }
      let!(:instance) { FactoryBot.create(:models_instance, deployment: deployment, job: 'fake-job', index: 0, availability_zone: 'az1') }
      let(:disk_owners) do
        { 'fake-disk-cid' => ['fake-vm-cid'] }
      end
      before do
        allow(cloud).to receive(:has_disk).and_return(true)
        instance.active_vm = vm
      end

      context 'when cloud does not have disk' do
        before { allow(cloud).to receive(:has_disk).and_return(false) }

        it 'registers missing disk problem' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to receive(:problem_found).with(:missing_disk, disk)
          expect(event_logger).to receive(:track_and_log).with('0 OK, 1 missing, 0 inactive, 0 mount-info mismatch')
          disk_scanner.scan
        end
      end

      context 'when instance is ignored' do
        let!(:instance) { FactoryBot.create(:models_instance, deployment: deployment, job: 'fake-job', index: 1, availability_zone: 'az1', ignore: true) }
        let(:disk_count) { 0 }

        it 'does not register missing disk problem' do
          expect(problem_register).to_not receive(:problem_found).with(:missing_disk, disk)
          expect(event_logger).to receive(:track_and_log).with('0 OK, 0 missing, 0 inactive, 0 mount-info mismatch')
          disk_scanner.scan
        end
      end

      context 'when cloud does not implement has_disk' do
        before do
          allow(cloud).to receive(:has_disk).and_raise(Bosh::Clouds::NotImplemented)
        end

        it 'does not register any problems' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to_not receive(:problem_found)
          disk_scanner.scan
        end
      end

      context 'when disk is inactive' do
        let(:disk_state) { false }

        it 'registers inactive disk problem' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to receive(:problem_found).with(:inactive_disk, disk)
          expect(event_logger).to receive(:track_and_log).with('0 OK, 0 missing, 1 inactive, 0 mount-info mismatch')
          disk_scanner.scan
        end
      end

      context 'when disk is associated with an instance with no VM' do
        before do
          instance.active_vm = nil
          instance.save
        end

        it 'reports no problems' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to_not receive(:problem_found)
          disk_scanner.scan
        end
      end

      context 'when disk is attached to different VM' do
        let(:disk_owners) do
          { disk.disk_cid => owner_vms }
        end
        let(:owner_vms) { ['different-vm-cid'] }

        it 'registers disk mount problem' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to receive(:problem_found).
            with(:mount_info_mismatch, disk, owner_vms: owner_vms)
          disk_scanner.scan
        end
      end
    end
  end
end
