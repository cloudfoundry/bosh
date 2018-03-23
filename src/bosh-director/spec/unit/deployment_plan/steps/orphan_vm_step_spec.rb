require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe OrphanVmStep do
        subject(:step) { described_class.new(vm) }

        let(:instance) { Models::Instance.make }
        let!(:vm) do
          Models::Vm.make(
            instance: instance,
            active: false,
            cpi: 'vm-cpi',
            stemcell_api_version: 9876
          )
        end
        let(:report) { double(:report) }

        it 'removes the vm record' do
          expect do
            step.perform(report)
          end.to change { Models::Vm.count }.by(-1)

          expect do
            vm.reload
          end.to raise_error
        end

        it 'creates an orphaned vm record' do
          expect do
            step.perform(report)
          end.to change { Models::OrphanedVm.count }.by(1)

          orphaned_vm = Models::OrphanedVm.last
          expect(orphaned_vm.availability_zone).to eq vm.instance.availability_zone
          expect(orphaned_vm.cid).to eq vm.cid
          expect(orphaned_vm.cloud_properties).to eq vm.instance.cloud_properties
          expect(orphaned_vm.cpi).to eq vm.cpi
          expect(orphaned_vm.instance_id).to eq instance.id
          expect(orphaned_vm.stemcell_api_version).to eq(9876)
          expect(orphaned_vm.orphaned_at).to be_a Time
        end

        it 'moves ips over to the orphaned vm' do
          ip1 = Models::IpAddress.make(vm: vm, address_str: '1.1.1.1')
          ip2 = Models::IpAddress.make(vm: vm, address_str: '2.2.2.2')
          expect(vm.ip_addresses.count).to eq 2
          step.perform(report)
          orphaned_vm = Models::OrphanedVm.last
          expect(orphaned_vm.ip_addresses.count).to eq 2
          expect(orphaned_vm.ip_addresses).to contain_exactly(ip1, ip2)
          expect(ip1.reload.vm_id).to be_nil
          expect(ip2.reload.vm_id).to be_nil
        end
      end
    end
  end
end
