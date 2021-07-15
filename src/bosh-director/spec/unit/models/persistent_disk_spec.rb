require 'spec_helper'

module Bosh::Director::Models

  describe PersistentDisk do
    subject(:persistent_disk) {described_class.make(cpi:cpi)}
    let(:cpi) { 'my_cpi' }

    describe 'cloud_properties' do
      let(:disk_cloud_properties) do
        { 'fake-cloud-property-key' => 'fake-cloud-property-value' }
      end

      it 'updates cloud_properties' do
        persistent_disk.cloud_properties = disk_cloud_properties

        expect(persistent_disk.cloud_properties).to eq(disk_cloud_properties)
      end
    end
    describe 'CPI' do

      it 'return CPI' do
        expect(persistent_disk.cpi).to eq('my_cpi')
      end

      context 'when CPI is nil' do
        let(:cpi) { nil }
        let(:instance) { instance_double(Instance, cpi: 'instance_cpi')}
        before do
          allow(persistent_disk).to receive(:instance).and_return(instance)
          persistent_disk.cpi = nil
        end

        it 'return CPI of active VM' do
          expect(persistent_disk.cpi).to_not be_nil
          expect(persistent_disk.cpi).to eq(persistent_disk.instance.cpi)
        end
      end
    end
  end
end
