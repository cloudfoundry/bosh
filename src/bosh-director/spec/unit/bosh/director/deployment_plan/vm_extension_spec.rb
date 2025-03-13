require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe VmExtension do
    subject(:vm_extension) { VmExtension.new(valid_spec) }

    let(:valid_spec) do
      {
        'name' => 'small',
        'cloud_properties' => { 'foo' => 'bar' },
      }
    end

    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe 'creating' do
      it 'parses name, cloud properties' do
        expect(vm_extension.name).to eq('small')
        expect(vm_extension.cloud_properties).to eq({ 'foo' => 'bar' })
      end

      context 'when name is missing' do
        before { valid_spec.delete('name') }

        it 'raises an error' do
          expect { VmExtension.new(valid_spec) }.to raise_error(Bosh::Director::ValidationMissingField)
        end
      end

      context 'when cloud_properties is missing' do
        before { valid_spec.delete('cloud_properties') }

        it 'defaults to empty hash' do
          expect(vm_extension.cloud_properties).to eq({})
        end
      end

      context 'when cloud_properties is NOT a hash' do
        before { valid_spec['cloud_properties'] = 'not_hash' }

        it 'raises an error' do
          expect{
            subject
          }.to raise_error(Bosh::Director::ValidationInvalidType)
        end
      end
    end

    it 'returns vm extension spec as Hash' do
      expect(vm_extension.spec).to eq({
        'name' => 'small',
        'cloud_properties' => { 'foo' => 'bar' },
      })
    end

  end
end
