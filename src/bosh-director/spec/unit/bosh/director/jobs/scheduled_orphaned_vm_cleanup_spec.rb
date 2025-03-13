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
        let(:job) { ScheduledOrphanedVMCleanup.new }
        let(:orphaned_vm_deleter) { instance_double(Bosh::Director::OrphanedVMDeleter) }
        let(:lock_timeout) { 1 }

        before do
          allow(Bosh::Director::OrphanedVMDeleter).to receive(:new).and_return(orphaned_vm_deleter)
        end

        it 'deletes all orphaned vms' do
          expect(orphaned_vm_deleter).to receive(:delete_all).with(lock_timeout)

          job.perform(lock_timeout)
        end
      end
    end
  end
end
