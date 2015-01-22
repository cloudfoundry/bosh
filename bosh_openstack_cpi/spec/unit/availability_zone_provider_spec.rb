require 'spec_helper'

describe Bosh::OpenStackCloud::AvailabilityZoneProvider do
  let(:foo_volume) { double('foo_volume') }
  let(:bar_volume) { double('bar_volume') }
  let(:volumes) { double('volumes') }
  let(:openstack) { double(Fog::Compute) }
  let(:az_provider) { Bosh::OpenStackCloud::AvailabilityZoneProvider.new(openstack, ignore_server_az) }

  before do
    allow(foo_volume).to receive(:availability_zone).and_return('west_az')
    allow(volumes).to receive(:get).with('foo_id').and_return(foo_volume)
    allow(volumes).to receive(:get).with('bar_id').and_return(bar_volume)
    allow(openstack).to receive(:volumes).and_return(volumes)
  end

  describe 'when the server availability zone of the server must be the same as the disk' do
    let(:ignore_server_az) { false }

    describe 'when the volume IDs are present' do
      describe 'when the volumes and resource pool are all from the same availability zone' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it "should return the disk's availability zone" do
          selected_availability_zone = az_provider.select(['foo_id', 'bar_id'], 'west_az')
          expect(selected_availability_zone).to eq('west_az')
        end
      end

      describe 'when the disks are from different AZs and no resource pool AZ is provided' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(['foo_id', 'bar_id'], nil)
          }.to raise_error(Bosh::Clouds::CloudError)
        end
      end

      describe 'when the disks are from the same AZ and no resource pool AZ is provided' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it 'should select the common disk AZ' do
          selected_availability_zone = az_provider.select(['foo_id', 'bar_id'], nil)
          expect(selected_availability_zone).to eq('west_az')
        end
      end

      describe 'when there is a volume in a different AZ from other volumes or the resource pool AZ' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(['foo_id', 'bar_id'], 'west_az')
          }.to raise_error(Bosh::Clouds::CloudError)
        end
      end

      describe 'when the disk AZs do not match the resource pool AZ' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('west_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(['foo_id', 'bar_id'], 'south_az')
          }.to raise_error(Bosh::Clouds::CloudError)
        end
      end

      describe 'when all AZs provided are mismatched' do
        before do
          expect(bar_volume).to receive(:availability_zone).and_return('east_az')
        end

        it 'should raise an error' do
          expect {
            az_provider.select(['foo_id', 'bar_id'], 'south_az')
          }.to raise_error(Bosh::Clouds::CloudError)
        end
      end

      describe 'when there are no disks IDs' do
        it 'should return the resource pool AZ value' do
          expect(az_provider.select([], nil)).to eq nil
          expect(az_provider.select([], 'north_az')).to eq 'north_az'

          expect(az_provider.select(nil, 'north_az')).to eq 'north_az'
        end
      end
    end
  end

  describe 'when the server availability zone of the server can be different from the disk' do
    let(:ignore_server_az) { true }

    it 'should return the resource pool availabilty zone' do
      selected_availability_zone = az_provider.select(['foo_id', 'bar_id'], 'north_id')
      expect(selected_availability_zone).to eq('north_id')
    end
  end
end
