require 'spec_helper'

module Bosh
  module Director
    describe OrphanedVMDeleter do
      subject { OrphanedVMDeleter.new(per_spec_logger) }

      describe '#delete_all' do
        let!(:orphaned_vm1) do
          Models::OrphanedVm.create(
            cid: 'cid1',
            orphaned_at: Time.now,
            stemcell_api_version: 1,
            deployment_name: 'fake-deployment-1',
            instance_name: 'fake-instance-1/fake-uuid-1',
            cpi: 'jims-cpi',
          )
        end
        let!(:ip_address1) do
          Bosh::Director::Models::IpAddress.create(
            orphaned_vm: orphaned_vm1,
            network_name: 'my-manual-network',
            address_str: Bosh::Director::IpAddrOrCidr.new('127.0.0.2/32').to_cidr_s,
            task_id: 1,
          )
        end
        let!(:orphaned_vm2) do
          Models::OrphanedVm.create(
            cid: 'cid2',
            orphaned_at: Time.now,
            stemcell_api_version: 2,
            deployment_name: 'fake-deployment-1',
            instance_name: 'fake-instance-2/fake-uuid-1',
            cpi: 'joshs-cpi',
          )
        end
        let!(:ip_address2) do
          Bosh::Director::Models::IpAddress.create(
            orphaned_vm: orphaned_vm2,
            network_name: 'my-manual-network',
            address_str: Bosh::Director::IpAddrOrCidr.new('127.0.0.1/32').to_cidr_s,
            task_id: 1,
          )
        end
        let(:vm_deleter) { instance_double(Bosh::Director::VmDeleter, delete_vm_by_cid: true) }
        let(:db_ip_repo) { Bosh::Director::DeploymentPlan::IpRepo.new(fake_logger) }
        let(:fake_logger) { instance_double(Logger, debug: true) }
        let(:task) { FactoryBot.create(:models_task, id: 42, username: 'foo') }
        let(:event_manager) { Api::EventManager.new(true) }
        let(:cleanup_job) do
          instance_double(
            Bosh::Director::Jobs::ScheduledOrphanedDiskCleanup,
            username: task.username,
            task_id: task.id,
            event_manager: event_manager,
          )
        end

        before do
          allow(Config).to receive(:current_job).and_return(cleanup_job)

          allow(Bosh::Director::VmDeleter).to receive(:new).and_return(vm_deleter)
          allow(Bosh::Director::DeploymentPlan::IpRepo).to receive(:new).and_return(db_ip_repo)
        end

        it 'deletes the orphaned vms by cid' do
          subject.delete_all
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi')
          expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
          expect(Models::OrphanedVm.count).to eq(0)
        end

        it 'releases the ip address used by the vm' do
          subject.delete_all
          expect(Bosh::Director::Models::IpAddress.first(address_str: IPAddr.new('127.0.0.1').to_i.to_s)).to be_nil
          expect(Bosh::Director::Models::IpAddress.first(address_str: IPAddr.new('127.0.0.2').to_i.to_s)).to be_nil
        end

        it 'records bosh event for vm deletion' do
          subject.delete_all

          expect(Models::Event.all.count).to eq(4)

          base_event_fields = {
            user: 'foo',
            action: 'delete',
            object_type: 'vm',
            task: '42',
            error: nil,
          }

          orphaned_vm1_event = Bosh::Director::Models::Event.where(
            base_event_fields.merge(
              parent_id: nil,
              object_name: orphaned_vm1.cid,
              deployment: 'fake-deployment-1',
              instance: 'fake-instance-1/fake-uuid-1',
            ),
          ).first
          expect(orphaned_vm1_event).to_not be_nil

          expect(
            Bosh::Director::Models::Event.where(
              base_event_fields.merge(
                parent_id: orphaned_vm1_event.id,
                object_name: orphaned_vm1.cid,
                deployment: 'fake-deployment-1',
                instance: 'fake-instance-1/fake-uuid-1',
              ),
            ),
          ).to_not be_nil

          orphaned_vm2_event = Bosh::Director::Models::Event.where(
            base_event_fields.merge(
              parent_id: nil,
              object_name: orphaned_vm2.cid,
              deployment: 'fake-deployment-1',
              instance: 'fake-instance-2/fake-uuid-1',
            ),
          ).first
          expect(orphaned_vm2_event).to_not be_nil

          expect(
            Bosh::Director::Models::Event.where(
              base_event_fields.merge(
                parent_id: orphaned_vm2_event.id,
                object_name: orphaned_vm2.cid,
                deployment: 'fake-deployment-1',
                instance: 'fake-instance-2/fake-uuid-1',
              ),
            ),
          ).to_not be_nil
        end

        context 'when deleting the vm fails' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise Bosh::Clouds::VMNotFound
          end

          it 'continues deleting orphaned vms' do
            subject.delete_all
            expect(vm_deleter).to have_received(:delete_vm_by_cid).with('cid2', 2, 'joshs-cpi')
          end

          it 'reports the failure' do
            subject.delete_all
            expect(Bosh::Director::Models::Event.where(
              user: task.username,
              action: 'delete',
              object_type: 'vm',
              object_name: orphaned_vm1.cid,
              error: 'Bosh::Clouds::VMNotFound',
              task: task.id.to_s,
            ).first).to_not be_nil
          end
        end

        context 'when there is an unhandled error' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise StandardError
          end

          it 'does not delete the orphaned vm record' do
            subject.delete_all
            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid1' }).to_not be_nil
          end
        end

        context 'when the vm does not exist' do
          before do
            allow(vm_deleter).to receive(:delete_vm_by_cid).with('cid1', 1, 'jims-cpi').and_raise Bosh::Clouds::VMNotFound
          end

          it 'deletes the model from the database' do
            subject.delete_all
            expect(Models::OrphanedVm.all.find { |vm| vm.cid == 'cid1' }).to be_nil
            expect(Bosh::Director::Models::IpAddress.first(address_str: IPAddr.new('127.0.0.1').to_i.to_s)).to be_nil
            expect(Bosh::Director::Models::IpAddress.first(address_str: IPAddr.new('127.0.0.2').to_i.to_s)).to be_nil
          end
        end

        context 'when the orphaned vm is already being deleted' do
          it 'skips deleting the orphaned vm but continues deleting the others' do
            Lock.new("lock:orphan_vm_cleanup:#{orphaned_vm1.cid}", timeout: 1).lock do
              subject.delete_all(0.1)
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
