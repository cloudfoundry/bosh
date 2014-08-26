require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  subject(:cloud) { described_class.new(options) }
  let(:options) do
    {
      'aws' => {
        'access_key_id' => 'keys to my heart',
        'secret_access_key' => 'open sesame',
        'region' => 'fake-region',
        'default_key_name' => 'sesame'
      },
      'registry' => {
        'user' => 'abuser',
        'password' => 'hard2gess',
        'endpoint' => 'http://websites.com'
      }
    }
  end

  let(:ec2) { instance_double('AWS::EC2', volumes: volumes) }
  before { allow(AWS::EC2).to receive(:new).and_return(ec2) }
  before { allow(ec2).to receive(:regions).and_return({'fake-region' => double(:region)}) }
  let(:volumes) { instance_double('AWS::EC2::VolumeCollection') }

  let(:az_selector) { instance_double('Bosh::AwsCloud::AvailabilityZoneSelector') }
  before { allow(Bosh::AwsCloud::AvailabilityZoneSelector).to receive(:new).and_return(az_selector) }

  describe 'validating initialization options' do
    context 'when options are invalid' do
      let(:options) do
        {
          'aws' => {
            'access_key_id' => 'keys to my heart',
            'secret_access_key' => 'open sesame'
          }
        }
      end

      it 'raises an error' do
        expect { cloud }.to raise_error(
          ArgumentError,
          'missing configuration parameters > aws:region, aws:default_key_name, registry:endpoint, registry:user, registry:password'
        )
      end
    end

    context 'when all the required configuraitons are present' do
      it 'does not raise an error ' do
        expect { cloud }.to_not raise_error
      end
    end
  end

  describe '#create_disk' do
    let(:cloud_properties) { {} }

    before do
      allow(az_selector).to receive(:select_availability_zone).
        with(42).and_return('fake-availability-zone')
    end

    let(:volume) { instance_double('AWS::EC2::Volume', id: 'fake-volume-id') }
    before do
      allow(Bosh::AwsCloud::ResourceWait).to receive(:for_volume).with(volume: volume, state: :available)
    end

    context 'when disk size us smaller than 1 GiB' do
      let(:disk_size) { 100 }

      it 'raises an error' do
        expect {
          cloud.create_disk(disk_size, cloud_properties, 42)
        }.to raise_error /AWS CPI minimum disk size is 1 GiB/
      end
    end

    context 'when disk size is greater than 1 TiB' do
      let(:disk_size) { 1025000 }

      it 'raises an error' do
        expect {
          cloud.create_disk(disk_size, cloud_properties, 42)
        }.to raise_error /AWS CPI maximum disk size is 1 TiB/
      end
    end

    context 'when disk size is between 1 GiB and 1 TiB' do
      let(:disk_size) { 1025 }

      context 'when disk type is provided' do
        let(:cloud_properties) { { 'type' => disk_type } }

        context 'when disk type is not gp2 or standard' do
          let(:disk_type) { 'non-existing-disk-type' }

          it 'raises an error' do
            expect {
              cloud.create_disk(disk_size, cloud_properties, 42)
            }.to raise_error /AWS CPI supports only gp2 or standard disk type/
          end
        end

        context 'when disk type is gp2' do
          let(:disk_type) { 'gp2' }

          it 'creates disk with gp2 type' do
            expect(ec2.volumes).to receive(:create).with(
              size: 2,
              availability_zone: 'fake-availability-zone',
              volume_type: 'gp2'
            ).and_return(volume)
            cloud.create_disk(disk_size, cloud_properties, 42)
          end
        end

        context 'when disk type is standard' do
          let(:disk_type) { 'standard' }

          it 'creates disk with standard type' do
            expect(ec2.volumes).to receive(:create).with(
              size: 2,
              availability_zone: 'fake-availability-zone',
              volume_type: 'standard'
            ).and_return(volume)
            cloud.create_disk(disk_size, cloud_properties, 42)
          end
        end
      end

      context 'when disk type is not provided' do
        it 'creates disk with standard disk type' do
          expect(ec2.volumes).to receive(:create).with(
            size: 2,
            availability_zone: 'fake-availability-zone',
            volume_type: 'standard'
          ).and_return(volume)
          cloud.create_disk(disk_size, cloud_properties, 42)
        end
      end
    end
  end
end
