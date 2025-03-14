require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe AvailabilityZone do

    describe '#parse' do
      subject(:availability_zone) { AvailabilityZone.parse(availability_zone_spec) }

      let(:availability_zone_spec) do
        { 'name' => 'z1', 'cloud_properties' => { 'availability_zone' => 'us-east-1a' } }
      end

      describe 'creating' do
        it 'has the name and cloud properties' do
          expect(availability_zone.name).to eq('z1')
          expect(availability_zone.cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
        end

        it 'has name, cloud properties and cpi' do
          availability_zone_spec['cpi'] = 'cpi1'
          expect(availability_zone.name).to eq('z1')
          expect(availability_zone.cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
          expect(availability_zone.cpi).to eq('cpi1')
        end
      end

      describe 'name' do
        context 'is not present' do
          let(:availability_zone_spec) do
            { 'cloud_properties' => {} }
          end

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(Bosh::Director::ValidationMissingField)
          end
        end

        context 'is not a string' do
          let(:availability_zone_spec) do
            { 'name' => {}, 'cloud_properties' => {} }
          end

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(Bosh::Director::ValidationInvalidType)
          end
        end
      end

      describe 'comparison' do
        context 'lesser' do
          let(:other) { AvailabilityZone.new("z2", {}) }

          it 'compares based on the name' do
            expect([other, subject].sort).to eql([subject, other])
          end
        end

        context 'greater' do
          let(:other) { AvailabilityZone.new("z0", {}) }

          it 'compares based on the name' do
            expect([other, subject].sort).to eql([other, subject])
          end
        end
      end

      describe 'cloud_properties' do

        context 'is not present' do
          let(:availability_zone_spec) do
            { 'name' => 'z1' }
          end

          it 'defaults to empty hash' do
            expect(availability_zone.cloud_properties).to eq({})
          end
        end

        context 'is not a hash' do
          let(:availability_zone_spec) do
            { 'name' => {}, 'cloud_properties' => 'myproperty' }
          end

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(Bosh::Director::ValidationInvalidType)
          end
        end
      end

      describe 'cpi' do
        context 'is not a string' do
          let(:availability_zone_spec) do
            { 'name' => 'z1', 'cpi' => [1, 2] }
          end

          it 'raises error' do
            expect { AvailabilityZone.parse(availability_zone_spec) }.to raise_error(Bosh::Director::ValidationInvalidType)
          end
        end
      end
    end
  end
end
