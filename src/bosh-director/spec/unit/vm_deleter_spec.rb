require 'spec_helper'

module Bosh
  module Director
    describe VmDeleter do
      subject { VmDeleter.new(logger) }

      let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
      let(:cloud_factory) { instance_double(CloudFactory) }
      let(:deployment) { FactoryBot.create(:models_deployment, name: 'deployment_name') }
      let(:vm_model) { Models::Vm.make(cid: 'vm-cid', instance_id: instance_model.id, cpi: 'cpi1') }
      let(:instance_model) do
        FactoryBot.create(:models_instance,
          uuid: SecureRandom.uuid,
          index: 5,
          job: 'fake-job',
          deployment: deployment,
          availability_zone: 'az1',
          spec_json: JSON.generate(spec_json),
        )
      end

      let(:spec_json) do
        { 'update' => { 'vm_strategy' => 'delete-create' } }
      end

      before do
        instance_model.active_vm = vm_model
        instance_model.reload

        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud_factory).to receive(:get).with(nil, nil).and_return(cloud)
      end

      describe '#delete_for_instance' do
        context 'when there are vms' do
          let(:vm_model2) { Models::Vm.make(cid: 'vm-cid2', instance_id: instance_model.id, cpi: 'cpi1') }

          before do
            vm_model.update(active: true)
          end

          context 'when the instance is orphanable' do
            let(:orphan_step) { instance_double(DeploymentPlan::Steps::OrphanVmStep, perform: true) }
            let(:unmount_step) { instance_double(DeploymentPlan::Steps::UnmountInstanceDisksStep, perform: true) }
            let(:detach_step) { instance_double(DeploymentPlan::Steps::DetachInstanceDisksStep, perform: true) }

            let(:spec_json) do
              { 'update' => { 'vm_strategy' => 'create-swap-delete' } }
            end

            context 'and async is true' do
              it 'orphans the vms' do
                expect(DeploymentPlan::Steps::UnmountInstanceDisksStep).to receive(:new)
                  .with(instance_model).and_return(unmount_step)
                expect(DeploymentPlan::Steps::DetachInstanceDisksStep).to receive(:new)
                  .with(instance_model).and_return(detach_step)
                expect(DeploymentPlan::Steps::OrphanVmStep).to receive(:new)
                  .with(vm_model).and_return(orphan_step)
                expect(DeploymentPlan::Steps::OrphanVmStep).to receive(:new)
                  .with(vm_model2).and_return(orphan_step)

                subject.delete_for_instance(instance_model, true, true)
              end
            end

            context 'and async is false' do
              let(:step) { instance_double(DeploymentPlan::Steps::DeleteVmStep) }

              it 'deletes the vms' do
                expect(DeploymentPlan::Steps::DeleteVmStep).to receive(:new).with(true, false, false).and_return(step)
                expect(step).to receive(:perform)

                subject.delete_for_instance(instance_model, true, false)
              end
            end
          end

          context 'when the instance is not orphanable' do
            let(:step) { instance_double(DeploymentPlan::Steps::DeleteVmStep) }

            it 'deletes the VMs immediately' do
              expect(DeploymentPlan::Steps::DeleteVmStep).to receive(:new).with(true, false, false).and_return(step)
              expect(step).to receive(:perform)

              subject.delete_for_instance(instance_model)
            end
          end
        end
      end

      describe '#delete_vm_by_cid' do
        context('deletes the vm using the appropriate cpi') do
          before do
            allow(cloud_factory).to receive(:get).with('cpi1', 25).and_return(cloud)
          end

          it 'calls delete_vm' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(cloud).to receive(:delete_vm).with(vm_model.cid)
            subject.delete_vm_by_cid(vm_model.cid, 25, 'cpi1')
          end

          context 'when virtual delete is enabled' do
            subject { VmDeleter.new(logger, false, true) }

            it 'skips calling delete_vm on the cloud' do
              expect(logger).to receive(:info).with('Deleting VM')
              expect(cloud).not_to receive(:delete_vm)
              subject.delete_vm_by_cid(vm_model.cid, nil)
            end
          end
        end
      end
    end
  end
end
