require 'spec_helper'


module Bosh::Director
  describe Errand::ErrandInstanceUpdater do
    subject(:updater) { Errand::ErrandInstanceUpdater.new(instance_group_manager, per_spec_logger, errand_name, deployment_name) }

    let(:instance_group_manager) { instance_double(Errand::InstanceGroupManager) }
    let(:deployment_name) { 'some-deployment' }
    let(:errand_name) { 'errand-name' }

    before do
      allow(instance_group_manager).to receive(:update_instances)
      allow(instance_group_manager).to receive(:create_missing_vms)
      allow(instance_group_manager).to receive(:delete_vms)
      allow(per_spec_logger).to receive(:info)
    end

    describe 'create_vms' do
      it 'creates vms' do
        expect(instance_group_manager).to receive(:create_missing_vms)
        updater.create_vms(true)
      end

      context 'when creating vms raises an error' do
        before do
          expect(instance_group_manager).to receive(:create_missing_vms).and_raise(RuntimeError, 'omg')
        end

        context 'when keep alive is true' do
          it 'logs a message but does not delete' do
            expect(per_spec_logger).to receive(:info).with('Skipping vms deletion, keep-alive is set')
            expect { updater.create_vms(true) }.to raise_error('omg')
          end
        end

        context 'when keep alive is false' do
          it 'cleans up the vms and logs a message' do
            expect(per_spec_logger).to receive(:info).with('Deleting vms')
            expect(instance_group_manager).to receive(:delete_vms)
            expect { updater.create_vms(false) }.to raise_error('omg')
          end

          it 'ignore cancellation should return true while deletion is happening' do
            expect_delete_vms_while_ignoring_cancellation(updater, instance_group_manager)
            expect { updater.create_vms(false) }.to raise_error('omg')
          end
        end

        context 'when cleaning up vms raises an error' do
          before do
            expect(instance_group_manager).to receive(:delete_vms).and_raise(RuntimeError, 'no delete for you')
          end

          it 'outputs a warning' do
            expect(per_spec_logger).to receive(:warn).with(/Failed to delete vms: RuntimeError: no delete for you/)
            expect { updater.create_vms(false) }.to raise_error('omg')
          end
        end
      end
    end

    describe '#with_updated_instances' do
      let(:errand_result) { instance_double(Errand::Result, exit_code: 42) }
      before do
        current_job = instance_double(Jobs::BaseJob,
          username: 'some-name',
          event_manager: Api::EventManager.new(true),
          task_id: 'some-id'
        )
        allow(Config).to receive(:current_job).and_return(current_job)
        allow(instance_group_manager).to receive(:update_instances)
      end

      it 'updates the instances and then runs the block' do
        expect(instance_group_manager).to receive(:update_instances)
        result = updater.with_updated_instances(false) { errand_result }
        expect(result).to eq(errand_result)
      end

      it 'cleanups up the vms afterward' do
        expect_delete_vms_while_ignoring_cancellation(updater, instance_group_manager)
        updater.with_updated_instances(false) { errand_result }
      end

      context 'when updating instances errors' do
        before do
          allow(instance_group_manager).to receive(:update_instances).and_raise(RuntimeError, 'omg')
        end

        context 'when keep alive is true' do
          let(:keep_alive) { true }
          it 'does not delete the vm, but does log a warning' do
            expect(per_spec_logger).to receive(:info).with('Skipping vms deletion, keep-alive is set')
            expect { updater.with_updated_instances(keep_alive) {} }.to raise_error(RuntimeError, 'omg')
          end
        end

        context 'when keep alive is false' do
          let(:keep_alive) { false }
          it 'cleans up the vms before propagating the error' do
            expect_delete_vms_while_ignoring_cancellation(updater, instance_group_manager)
            expect { updater.with_updated_instances(keep_alive) {} }.to raise_error(RuntimeError, 'omg')
          end
        end
      end

      context 'when running the block errors' do
        context 'when keep alive is false' do
          let(:keep_alive) { false }

          it 'cleanups up the vms afterward' do
            expect_delete_vms_while_ignoring_cancellation(updater, instance_group_manager)
            expect do
              updater.with_updated_instances(keep_alive) { raise RuntimeError, 'omg' }
            end.to raise_error(RuntimeError, 'omg')
          end
        end

        context 'when keep alive is true' do
          let(:keep_alive) { true }

          it 'logs an error' do
            expect(per_spec_logger).to receive(:info).with('Skipping vms deletion, keep-alive is set')
            expect do
              updater.with_updated_instances(keep_alive) { raise RuntimeError, 'omg' }
            end.to raise_error(RuntimeError, 'omg')
          end
        end
      end
    end
  end
end

def expect_delete_vms_while_ignoring_cancellation(updater, instance_group_manager)
  expect(updater.ignore_cancellation?).to be(false)
  expect(instance_group_manager).to receive(:delete_vms) do
    expect(updater.ignore_cancellation?).to be(true)
  end
  expect(updater.ignore_cancellation?).to be(false)
end
