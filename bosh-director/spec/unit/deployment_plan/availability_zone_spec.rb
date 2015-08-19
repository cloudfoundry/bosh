require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe AvailabilityZone do

    describe '#parse' do
      subject(:availability_zone) { AvailabilityZone.parse(availability_zone_spec) }

      let(:availability_zone_spec) { {'name' => 'z1', 'cloud_properties' => {'availability_zone' => 'us-east-1a'}} }

      describe 'creating' do
        it 'has the name and cloud properties' do
          expect(availability_zone.name).to eq('z1')
          expect(availability_zone.cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
        end
      end

      describe 'name' do
        context 'is not present' do
          let(:availability_zone_spec) { {'cloud_properties' => {}} }

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(BD::ValidationMissingField)
          end
        end

        context 'is not a string' do
          let(:availability_zone_spec) { {'name' => {}, 'cloud_properties' => {}} }

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(BD::ValidationInvalidType)
          end
        end
      end

      describe 'cloud_properties' do

        context 'is not present' do
          let(:availability_zone_spec) { {'name' => 'z1'} }

          it 'defaults to empty hash' do
            expect(availability_zone.cloud_properties).to eq({})
          end
        end

        context 'is not a hash' do
          let(:availability_zone_spec) { {'name' => {}, 'cloud_properties' => 'myproperty'} }

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(BD::ValidationInvalidType)
          end
        end
      end
    end
  end
end
