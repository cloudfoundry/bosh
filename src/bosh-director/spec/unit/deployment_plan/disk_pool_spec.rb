require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DiskType do
    describe 'parse' do
      describe 'disk_size' do
        context 'when size is negative' do
          let(:spec) { {'name' => 'fake-name', 'disk_size' => -100} }

          it 'raises an error' do
            expect {
              described_class.parse(spec)
            }.to raise_error
          end
        end

        context 'when size is not set' do
          let(:spec) { {'name' => 'fake-name' } }

          it 'raises an error' do
            expect {
              described_class.parse(spec)
            }.to raise_error(ValidationMissingField)
          end
        end

        context 'when size is set correctly' do
          let(:spec) { {'name' => 'fake-name', 'disk_size' => 42} }

          it 'sets the size' do
            disk_pool = described_class.parse(spec)
            expect(disk_pool.spec['disk_size']).to eq(42)
          end
        end
      end

      describe 'cloud_properties' do
        context 'when cloud_properties is not set' do
          let(:spec) do
            {
              'name' => 'fake-name',
              'disk_size' => 100,
            }
          end

          it 'sets it as hash' do
            disk_pool = described_class.parse(spec)
            expect(disk_pool.spec['cloud_properties']).to eq({})
          end
        end

        context 'when cloud_properties are set' do
          let(:spec) do
            {
              'name' => 'fake-name',
              'disk_size' => 100,
              'cloud_properties' => {
                'type' => 'standard'
              }
            }
          end

          it 'accepts cloud properties as hash' do
            disk_pool = described_class.parse(spec)
            expect(disk_pool.spec['cloud_properties']).to eq({'type' => 'standard'})
          end

          context 'when cloud_properties is not a hash' do
            let(:spec) do
              {
                'name' => 'fake-name',
                'disk_size' => 100,
                'cloud_properties' => 'string-property'
              }
            end

            it 'raises an error' do
              expect {
                described_class.parse(spec)
              }.to raise_error
            end
          end
        end
      end
    end
  end
end
