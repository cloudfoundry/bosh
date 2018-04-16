require 'spec_helper'

module Bosh::Director
  module Jobs
    describe ScheduledOrphanedVMCleanup do
      describe 'has_work' do
        context 'when there is an orphaned vm' do
          before do
            Models::OrphanedVm.create(
              cid: 'i-am-a-cid',
              orphaned_at: Time.now,
            )
          end

          it 'returns true' do
            expect(ScheduledOrphanedVMCleanup.has_work(nil)).to be_truthy
          end
        end

        context 'when there are no orphaned vms' do
          it 'returns false' do
            expect(ScheduledOrphanedVMCleanup.has_work(nil)).to be_falsey
          end
        end
      end

      describe 'perform' do
        let!(:orphaned_vm1) do
          Models::OrphanedVm.create(
            cid: 'cid1',
            orphaned_at: Time.now,
            stemcell_api_version: 1,
            cpi: 'jims-cpi',
          )
        end

        let!(:ip_address1) do
          Bosh::Director::Models::IpAddress.create(
            orphaned_vm: orphaned_vm1,
            network_name: 'my-manual-network',
            address_str: NetAddr::CIDR.create('127.0.0.2').to_i,
            task_id: 1,
          )
        end

        let!(:orphaned_vm2) do
          Models::OrphanedVm.create(
            cid: 'cid2',
            orphaned_at: Time.now,
            stemcell_api_version: 2,
            cpi: 'joshs-cpi',
          )
        end

        let!(:ip_address2) do
          Bosh::Director::Models::IpAddress.create(
            orphaned_vm: orphaned_vm2,
            network_name: 'my-manual-network',
            address_str: NetAddr::CIDR.create('127.0.0.1').to_i,
            task_id: 1,
          )
        end

        let(:vm_deleter) { instance_double(Bosh::Director::VmDeleter, delete_vm_by_cid: true) }
        let(:job) { ScheduledOrphanedVMCleanup.new({}) }
        let(:db_ip_repo) { Bosh::Director::DeploymentPlan::DatabaseIpRepo.new(fake_logger) }
        let(:fake_logger) { instance_double(Logger, debug: true) }
        let(:task) { Models::Task.make(id: 42, username: 'foo') }
        let(:event_manager) { Api::EventManager.new(true) }
        let(:cleanup_job) do
          instance_double(
            Bosh::Director::Jobs::ScheduledOrphanedDiskCleanup,
            username: task.username,
            task_id: task.id,
            event_manager: event_manager,
          )
        end

        before { allow(Config).to receive(:current_job).and_return(cleanup_job) }

        before do
          allow(Bosh::Director::VmDeleter).to receive(:new).and_return(vm_deleter)
          allow(Bosh::Director::DeploymentPlan::DatabaseIpRepo).to receive(:new).and_return(db_ip_repo)
        end

        it 'deletes the orphaned vms by cid' do
          job.perform
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi')
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
          expect(Models::OrphanedVm.count).to eq(0)
        end

        it 'releases the ip address used by the vm' do
          job.perform
          expect(Bosh::Director::Models::IpAddress.first(address_str: NetAddr::CIDR.create('127.0.0.1').to_i.to_s)).to be_nil
          expect(Bosh::Director::Models::IpAddress.first(address_str: NetAddr::CIDR.create('127.0.0.2').to_i.to_s)).to be_nil
        end

        it 'records bosh event for vm deletion' do
          job.perform

          expect(Models::Event.all.count).to eq(2)

          event1 = Bosh::Director::Models::Event.first
          expect(event1.user).to eq(task.username)
          expect(event1.action).to eq('delete')
          expect(event1.object_type).to eq('vm')
          expect(event1.object_name).to eq(orphaned_vm1.cid)
          expect(event1.error).to be_nil
          expect(event1.task).to eq(task.id.to_s)

          event2 = Bosh::Director::Models::Event.last
          expect(event2.user).to eq(task.username)
          expect(event2.action).to eq('delete')
          expect(event2.object_type).to eq('vm')
          expect(event2.object_name).to eq(orphaned_vm2.cid)
          expect(event2.error).to be_nil
          expect(event2.task).to eq(task.id.to_s)
        end

        context 'when deleting the vm fails' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise Bosh::Clouds::VMNotFound
          end

          it 'continues deleting orphaned vms' do
            job.perform
            expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
          end

          it 'reports the failure' do
            job.perform
            event1 = Bosh::Director::Models::Event.first
            expect(event1.user).to eq(task.username)
            expect(event1.action).to eq('delete')
            expect(event1.object_type).to eq('vm')
            expect(event1.object_name).to eq(orphaned_vm1.cid)
            expect(event1.error).to eq('Bosh::Clouds::VMNotFound')
            expect(event1.task).to eq(task.id.to_s)
          end
        end

        context 'when there is an unhandled error' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise StandardError
          end

          it 'does not delete the orphaned vm record' do
            job.perform
            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid1' }).to_not be_nil
          end
        end

        context 'when the vm does not exist' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise Bosh::Clouds::VMNotFound
          end

          it 'deletes the model from the database' do
            job.perform
            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid1' }).to be_nil
          end
        end

        context 'when the orphaned vm is already being deleted' do
          it 'skips deleting the orphaned vm but continues deleting the others' do
            Lock.new("lock:orphan_vm_cleanup:#{orphaned_vm1.cid}", timeout: 1).lock do
              job.perform(0.1)
            end

            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid1' }).to_not be_nil
            expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid2' }).to be_nil
          end
        end
      end
    end
  end
end
