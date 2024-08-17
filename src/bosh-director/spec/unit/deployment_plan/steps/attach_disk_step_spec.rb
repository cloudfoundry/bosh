require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe AttachDiskStep do
        subject(:step) { AttachDiskStep.new(disk, tags) }

        let(:stemcell_api_version) { 2 }
        let!(:vm) { FactoryBot.create(:models_vm, active: true, instance: instance, stemcell_api_version: stemcell_api_version) }
        let(:instance) { FactoryBot.create(:models_instance) }
        let!(:disk) { FactoryBot.create(:models_persistent_disk, instance: instance, name: '', cpi: 'my-cpi') }
        let(:cloud_factory) { instance_double(CloudFactory) }
        let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:metadata_updater_cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
        let(:tags) do
          { 'mytag' => 'myvalue' }
        end
        let(:meta_updater) { instance_double(MetadataUpdater, update_disk_metadata: nil) }
        let(:report) { instance_double(Stages::Report).as_null_object }
        let(:agent_client) { instance_double(AgentClient).as_null_object }

        before do
          allow(CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get).with(disk&.cpi, stemcell_api_version).once.and_return(cloud)
          allow(cloud_factory).to receive(:get).with(disk&.cpi).once.and_return(metadata_updater_cloud)
          allow(cloud).to receive(:attach_disk)
          allow(MetadataUpdater).to receive(:build).and_return(meta_updater)
          allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
        end

        it 'calls out to cpi associated with disk to attach disk' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi, stemcell_api_version).once.and_return(cloud)
          expect(cloud).to receive(:attach_disk).with(vm.cid, disk.disk_cid)

          step.perform(report)
        end

        it 'uses the cpi associated with disk' do
          expect(cloud_factory).to receive(:get).with(disk&.cpi).once
          expect(cloud_factory).to_not receive(:get_default_cloud)

          step.perform(report)
        end

        context 'update agent with persistent disk' do
          before do
            allow(cloud).to receive(:attach_disk).and_return(disk_hint)
          end

          context 'when the cpi returns a disk hint for attach disk' do
            let(:disk_hint) { 'foo' }
            it 'sends an add_persistent_disk message to agent' do
              expect(agent_client).to receive(:wait_until_ready)
              expect(agent_client).to receive(:add_persistent_disk).with(disk.disk_cid, disk_hint)
              step.perform(report)
            end
          end

          context 'when cpi returns a nil disk hint (old CPI, using registry)' do
            let(:disk_hint) { nil }
            it 'sends an add_persistent_disk message to agent' do
              expect(agent_client).to_not receive(:wait_until_ready)
              expect(agent_client).to_not receive(:add_persistent_disk).with(disk.disk_cid, disk_hint)
              step.perform(report)
            end
          end
        end

        it 'logs notification of attaching' do
          expect(logger).to receive(:info).with("Attaching disk #{disk.disk_cid}")

          step.perform(report)
        end

        it 'updates the disk metadata with given tags' do
          expect(meta_updater).to receive(:update_disk_metadata).with(metadata_updater_cloud, disk, tags)

          step.perform(report)
        end

        context 'when the CPI reports error when a disk is not able to be attached' do
          let(:cpi_error) { Bosh::Clouds::CloudError.new('cloud error') }

          before do
            allow(cloud).to receive(:attach_disk)
              .with(vm.cid, disk.disk_cid)
              .and_raise(cpi_error)
          end

          it 'raises a CloudDiskNotAttached error' do
            expect { step.perform(report) }.to raise_error(cpi_error)
          end
        end

        context 'when given nil disk' do
          let(:disk) { nil }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:attach_disk)

            step.perform(report)
          end
        end

        context 'when given disk with an instance that has no active vm' do
          let(:step) { AttachDiskStep.new(disk_without_vm, tags) }
          let(:instance_without_vm) { FactoryBot.create(:models_instance) }
          let!(:disk_without_vm) { FactoryBot.create(:models_persistent_disk, instance: instance_without_vm, name: 'no vm for me') }

          it 'does not perform any cloud actions' do
            expect(cloud).to_not receive(:attach_disk)

            step.perform(report)
          end
        end
      end
    end
  end
end
