require 'spec_helper'

describe Bosh::OpenStackCloud::Cloud do
  describe 'has_disk?' do
    context 'when disk is found' do
      let(:disk) { instance_double('Fog::Volume') }

      it 'returns true' do
        cloud = mock_cloud(mock_cloud_options['properties']) do |openstack|
          allow(openstack.volumes).to receive(:get).with('fake-disk-uuid').and_return(disk)
        end

        expect(cloud.has_disk?('fake-disk-uuid')).to be(true)
      end
    end

    context 'when disk is not found' do
      it 'returns false' do
        cloud = mock_cloud(mock_cloud_options['properties']) do |openstack|
          allow(openstack.volumes).to receive(:get).with('fake-disk-uuid').and_return(nil)
        end

        expect(cloud.has_disk?('fake-disk-uuid')).to be(false)
      end
    end
  end
end
