require 'spec_helper'

module Bosh::Director::Models
  describe PersistentDisk do
    describe 'cloud_properties' do
      subject(:persistent_disk) { PersistentDisk.new }

      let(:disk_cloud_properties) do
        { 'fake-cloud-property-key' => 'fake-cloud-property-value' }
      end

      it 'updates cloud_properties' do
        persistent_disk.cloud_properties = disk_cloud_properties

        expect(persistent_disk.cloud_properties).to eq(disk_cloud_properties)
      end
    end

    describe 'CPI' do
      subject(:persistent_disk) { PersistentDisk.new(cpi: cpi, instance: instance) }

      let(:cpi) { 'persistent-disc-cpi' }
      let(:instance) { FactoryBot.create(:models_instance) }

      it 'return CPI' do
        expect(persistent_disk.cpi).to eq(cpi)
      end

      context 'when CPI is nil' do
        let(:cpi) { nil }
        let(:vm_cpi) { 'vm-cpi' }

        before do
          FactoryBot.create(:models_vm, :active, instance: instance, cpi: vm_cpi)
        end

        it 'return CPI of active VM' do
          expect(persistent_disk.instance.cpi).to eq(vm_cpi)
          expect(persistent_disk.cpi).to eq(vm_cpi)
        end
      end
    end
  end
end
