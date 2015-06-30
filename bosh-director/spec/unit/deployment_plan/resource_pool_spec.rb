require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe ResourcePool do
    subject(:resource_pool) { ResourcePool.new(plan, valid_spec, logger) }
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

    let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network') }
    let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    before { allow(plan).to receive(:network).with('test').and_return(network) }

    describe 'creating' do
      it 'parses name, size, stemcell spec, cloud properties, env' do
        expect(resource_pool.name).to eq('small')
        expect(resource_pool.stemcell).to be_kind_of(Stemcell)
        expect(resource_pool.stemcell.name).to eq('stemcell-name')
        expect(resource_pool.stemcell.version).to eq('0.5.2')
        expect(resource_pool.network).to eq(network)
        expect(resource_pool.cloud_properties).to eq({ 'foo' => 'bar' })
        expect(resource_pool.env).to eq({ 'key' => 'value' })
      end

      context 'when name is missing' do
        before { valid_spec.delete('name') }

        it 'raises an error' do
          expect { ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ValidationMissingField)
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
            expect { ResourcePool.new(plan, valid_spec, logger) }.to_not raise_error
          end
        end
      end

      context 'when the deployment plan does not have the resource pool network' do
        before do
          valid_spec.merge!('network' => 'foobar')
          allow(plan).to receive(:network).with('foobar').and_return(nil)
        end

        it 'raises an error' do
          expect { ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ResourcePoolUnknownNetwork)
        end
      end

      context 'when the resource pool spec has no env' do
        before { valid_spec.delete('env') }

        it 'has default env' do
          expect(resource_pool.env).to eq({})
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
