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
          expect { VmExtension.new(valid_spec) }.to raise_error(BD::ValidationMissingField)
        end
      end

      context 'when cloud_properties is missing' do
        before { valid_spec.delete('cloud_properties') }

        it 'defaults to empty hash' do
          expect(vm_extension.cloud_properties).to eq({})
        end
      end

      context 'when cloud_properties is a placeholder' do
        before { valid_spec['cloud_properties'] = '((cloud_properties_placeholder))' }

        it 'does not error' do
          expect{
            subject
          }.to_not raise_error
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
