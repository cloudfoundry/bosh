require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe DetachDynamicDiskStep do
        subject(:step) { DetachDynamicDiskStep.new(disk) }

        let!(:vm) { FactoryBot.create(:models_vm, instance: instance, stemcell_api_version: 25) }
        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:disk) { FactoryBot.create(:models_dynamic_disk, vm: vm, name: 'disk-name') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:report) { Stages::Report.new }
        let(:agent_client) { instance_double(AgentClient) }

        before do
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          allow(cloud).to receive(:detach_disk)
          allow(agent_client).to receive(:remove_dynamic_disk)
          allow(AgentClient).to receive(:with_agent_id).with(vm.agent_id, instance.name).and_return(agent_client)
        end

        it 'calls out to cpi associated with disk to detach disk' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi, 25).once.and_return(cloud)
          expect(agent_client).to receive(:remove_dynamic_disk).with(disk.disk_cid)
          expect(cloud).to receive(:detach_disk).with(vm.cid, disk.disk_cid)

          step.perform(report)
        end

        it 'clears vm_cid from disk' do
          step.perform(report)
          expect(Models::DynamicDisk.find(disk_cid: disk.disk_cid).vm_id).to be_nil
        end

        it 'logs notification of detaching' do
          expect(per_spec_logger).to receive(:info).with("Detaching dynamic disk #{disk.disk_cid}")

          step.perform(report)
        end

        context 'when the CPI reports that a disk is not attached' do
          before do
            allow(cloud).to receive( :detach_disk)
                              .with(vm.cid, disk.disk_cid)
                              .and_raise(Bosh::Clouds::DiskNotAttached.new('foo'))
          end

          it 'raises a CloudDiskNotAttached error' do
            expect {
              step.perform(report)
            }.to raise_error(
                   CloudDiskNotAttached,
                   "'#{vm.cid}' VM should have dynamic disk '#{disk.disk_cid}' attached " \
                     "but it doesn't (according to CPI)",
                 )
          end
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(agent_client).to_not receive(:remove_dynamic_disk)
            expect(cloud).to_not receive(:detach_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
