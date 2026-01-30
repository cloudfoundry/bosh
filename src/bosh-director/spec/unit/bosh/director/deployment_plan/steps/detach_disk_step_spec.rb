require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DetachDiskStep do
        subject(:step) { DetachDiskStep.new(disk) }

        let!(:vm) { FactoryBot.create(:models_vm, active: true, instance: instance, stemcell_api_version: 25) }
        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:disk) { FactoryBot.create(:models_persistent_disk, instance: instance, name: '') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:report) { Stages::Report.new }
        let(:agent_client) do
          instance_double(AgentClient, list_disk: [disk&.disk_cid], remove_persistent_disk: nil)
        end
        let(:job) { instance_double(Bosh::Director::Jobs::BaseJob, username: 'user', task_id: 42) }

        before do
          allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, vm.instance.name).and_return(agent_client)
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          allow(cloud).to receive(:detach_disk)
          allow(Config).to receive(:current_job).and_return(job)
        end

        it 'sends remove_persistent_disk method to agent' do
          expect(agent_client).to receive(:remove_persistent_disk).with(disk.disk_cid)

          step.perform(report)
        end

        it 'calls out to cpi associated with disk to detach disk with vm lock' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          expect(step).to receive(:with_vm_lock).with(vm.cid).and_yield
          expect(cloud).to receive(:detach_disk).with(vm.cid, disk.disk_cid)

          step.perform(report)
        end

        it 'logs notification of detaching' do
          expect(per_spec_logger).to receive(:info).with("Detaching disk #{disk.disk_cid}")
          expect(per_spec_logger).to receive(:info).with("Acquiring VM lock on #{vm.cid}")

          step.perform(report)
        end

        context 'when the CPI reports that a disk is not attached' do
          before do
            allow(cloud).to receive(:detach_disk)
              .with(vm.cid, disk.disk_cid)
              .and_raise(Bosh::Clouds::DiskNotAttached.new('foo'))
          end

          context 'and the disk is active' do
            before do
              disk.update(active: true)
            end

            it 'raises a CloudDiskNotAttached error' do
              expect { step.perform(report) }.to raise_error(
                CloudDiskNotAttached,
                "'#{instance}' VM should have persistent disk '#{disk.disk_cid}' attached " \
                "but it doesn't (according to CPI)",
              )
            end
          end

          context 'and the disk is not active' do
            before do
              disk.update(active: false)
            end

            it 'does not raise any errors' do
              expect { step.perform(report) }.not_to raise_error
            end
          end
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:detach_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
