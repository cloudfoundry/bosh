require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe AvailabilityZone do

    describe '.parse' do

      let(:cloud_config) { { 'azs' => [{'name' => 'z1', 'cloud_properties' => {'availability_zone' => 'us-east-1a'}}] }}

      describe 'creating' do
        it 'has the name and cloud properties' do
          az = AvailabilityZone.parse(cloud_config).first

          expect(az.name).to eq('z1')
          expect(az.cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
        end

        it 'has name, cloud properties and cpi' do
          cloud_config['azs'].first['cpi'] = 'cpi1'
          az = AvailabilityZone.parse(cloud_config).first

          expect(az.name).to eq('z1')
          expect(az.cloud_properties).to eq({'availability_zone' => 'us-east-1a'})
          expect(az.cpi).to eq('cpi1')
        end
      end

      describe 'name' do
        context 'is not present' do
          let(:cloud_config) { { 'azs' => [{'cloud_properties' => {}}] } }

          it 'raises error' do
            expect { AvailabilityZone.parse(cloud_config) }.to raise_error(BD::ValidationMissingField)
          end
        end

        context 'is not a string' do
          let(:cloud_config) { { 'azs' => [{'name' => {}, 'cloud_properties' => {}}] } }

          it 'raises error' do
            expect { AvailabilityZone.parse(cloud_config) }.to raise_error(BD::ValidationInvalidType)
          end
        end
      end

      describe 'comparison' do
        context 'lesser' do
          let(:other) { AvailabilityZone.new("z2", {}) }

          it 'compares based on the name' do
            azs = AvailabilityZone.parse(cloud_config)

            expect([other, azs.first].sort).to eql([azs.first, other])
          end
        end

        context 'greater' do
          let(:other) { AvailabilityZone.new("z0", {}) }

          it 'compares based on the name' do
            azs = AvailabilityZone.parse(cloud_config)
            expect([other, azs.first].sort).to eql([other, azs.first])
          end
        end
      end

      describe 'cloud_properties' do

        context 'is not present' do
          let(:cloud_config) { { 'azs' => [{'name' => 'z1'}] } }

          it 'defaults to empty hash' do
            expect(AvailabilityZone.parse(cloud_config).first.cloud_properties).to eq({})
          end
        end

        context 'is not a hash' do
          let(:cloud_config) { { 'azs' => [{'name' => {}, 'cloud_properties' => 'myproperty'}] } }

          it 'raises error' do
            expect { AvailabilityZone.parse(cloud_config) }.to raise_error(BD::ValidationInvalidType)
          end
        end
      end

      describe 'cpi' do
        context 'is not a string' do
          let(:cloud_config) { { 'azs' => [{'name' => 'z1', 'cpi' => [1,2]}] } }

          it 'raises error' do
            expect { AvailabilityZone.parse(cloud_config) }.to raise_error(BD::ValidationInvalidType)
          end
        end
      end

      context 'when there are more than one azs' do
        let(:cloud_config) do
          {
              'azs' => [
                  {'name' => 'z1', 'cloud_properties' => {'availability_zone' => 'us-east-1a'}},
                  {'name' => 'z2', 'cloud_properties' => {'availability_zone' => 'us-east-1a'}},
                  {'name' => 'z3', 'cloud_properties' => {'availability_zone' => 'us-east-1a'}}
              ]
          }
        end

        it 'returns a list of availability_zones' do
          azs = AvailabilityZone.parse(cloud_config)

          expect(azs.length).to eq(3)
          expect(azs.map(&:name)).to eq(['z1','z2','z3'])
        end
      end

      context 'when cloud config does not contain azs' do
        let(:cloud_config) {{}}

        it 'returns an empty list of azs' do
          expect(AvailabilityZone.parse(cloud_config)).to be_empty
        end
      end

      context 'when cloud config contains empty azs' do
        let(:cloud_config) {{ 'azs' => []}}

        it 'returns an empty list of azs' do
          expect(AvailabilityZone.parse(cloud_config)).to be_empty
        end
      end
    end
  end
end
