require 'spec_helper'

module Bosh::Director::Models
  describe OrphanDisk do
    subject(:orphan_disk) { described_class.new }

    describe 'cloud_properties' do
      let(:disk_cloud_properties) do
        {
          'fake-cloud-property-key' => 'fake-cloud-property-value'
        }
      end

      it 'updates cloud_properties' do
        orphan_disk.cloud_properties = disk_cloud_properties

        expect(orphan_disk.cloud_properties).to eq(disk_cloud_properties)
      end
    end
  end
end
