require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe ResourcePool do
    subject(:resource_pool) { ResourcePool.new(valid_spec) }
    let(:max_size) { 2 }

    let(:valid_spec) do
      {
        'name' => 'small',
        'size' => max_size,
        'network' => 'test',
        'stemcell' => {
          'name' => 'stemcell-name',
          'version' => '0.5.2'
        },
        'cloud_properties' => { 'foo' => 'bar' },
        'env' => { 'key' => 'value' },
      }
    end

    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }


    describe 'creating' do
      it 'parses name, size, stemcell spec, cloud properties, env' do
        expect(resource_pool.name).to eq('small')
        expect(resource_pool.stemcell).to be_kind_of(Stemcell)
        expect(resource_pool.stemcell.name).to eq('stemcell-name')
        expect(resource_pool.stemcell.version).to eq('0.5.2')
        expect(resource_pool.cloud_properties).to eq({ 'foo' => 'bar' })
        expect(resource_pool.env).to eq({ 'key' => 'value' })
      end

      context 'when name is missing' do
        before { valid_spec.delete('name') }

        it 'raises an error' do
          expect { ResourcePool.new(valid_spec) }.to raise_error(BD::ValidationMissingField)
        end
      end

      context 'when stemcell name is missing' do
        before { valid_spec['stemcell'].delete('name') }

        it 'raises an error' do
          expect {
            ResourcePool.new(valid_spec)
          }.to raise_error(BD::ValidationMissingField)
        end
      end

      context 'when stemcell has an os' do
        before do
          valid_spec['stemcell'].delete('name')
          valid_spec['stemcell']['os'] = 'ubuntu-trusty'
        end

        it 'raises an error' do
          expect {
          ResourcePool.new(valid_spec)
          }.not_to raise_error
        end
      end

      context 'when cloud_properties is missing' do
        before { valid_spec.delete('cloud_properties') }

        it 'defaults to empty hash' do
          expect(resource_pool.cloud_properties).to eq({})
        end
      end

      %w(size).each do |key|
        context "when #{key} is missing" do
          before { valid_spec.delete(key) }

          it 'does not raise an error' do
            expect { ResourcePool.new(valid_spec) }.to_not raise_error
          end
        end
      end
    end

    it 'returns resource pool spec as Hash' do
      expect(resource_pool.spec).to eq({
        'name' => 'small',
        'cloud_properties' => { 'foo' => 'bar' },
        'stemcell' => { 'name' => 'stemcell-name', 'version' => '0.5.2' }
      })
    end

  end
end
