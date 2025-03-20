require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe DiskType do

    let(:valid_spec) do
      {
        'name' => 'small',
        'disk_size' => 2,
        'cloud_properties' => { 'foo' => 'bar' },
      }
    end

    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe 'parse' do
      it 'parses name, disk size and cloud properties' do
        disk_type = DiskType.parse(valid_spec)
        expect(disk_type.name).to eq('small')
        expect(disk_type.disk_size).to eq(2)
        expect(disk_type.cloud_properties).to eq({ 'foo' => 'bar' })
      end

      it 'returns disk type spec as Hash' do
        disk_type = DiskType.parse(valid_spec)
        expect(disk_type.spec).to eq({
           'name' => 'small',
           'disk_size' => 2,
           'cloud_properties' => { 'foo' => 'bar' },
         })
      end

      describe 'name' do
        context 'when name is missing' do
          before { valid_spec.delete('name') }

          it 'raises an error' do
            expect {
              DiskType.parse(valid_spec)
            }.to raise_error(Bosh::Director::ValidationMissingField)
          end
        end
      end

      describe 'disk_size' do
        context 'when disk_size is missing' do
          before { valid_spec.delete('disk_size') }

          it 'raises an error' do
            expect {
              DiskType.parse(valid_spec)
            }.to raise_error(Bosh::Director::ValidationMissingField)
          end
        end

        context 'when disk_size is less than 0' do
          before { valid_spec['disk_size'] = -2 }

          it 'raises an error' do
            expect {
              DiskType.parse(valid_spec)
            }.to raise_error(Bosh::Director::DiskTypeInvalidDiskSize)
          end
        end
      end

      describe 'cloud_properties' do
        context 'when cloud_properties is missing' do
          before { valid_spec.delete('cloud_properties') }

          it 'defaults to empty hash' do
            disk_type = DiskType.parse(valid_spec)
            expect(disk_type.cloud_properties).to eq({})
          end
        end

        context 'when cloud_properties is NOT a hash' do
          before { valid_spec['cloud_properties'] = 'not_hash' }

          it 'raises an error' do
            expect{
              DiskType.parse(valid_spec)
            }.to raise_error(Bosh::Director::ValidationInvalidType)
          end
        end
      end
    end
  end
end
