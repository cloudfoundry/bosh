require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentValidator do
    describe '#validate' do
      let(:deployment) { instance_double(DeploymentPlan::Planner, {manifest_hash: manifest_hash, }) }
      let(:deployment_validator) { DeploymentPlan::DeploymentValidator.new }

      let(:cloud_config) { Models::CloudConfig.make }

      let(:deployment) do
        instance_double(DeploymentPlan::Planner,
          {
            resource_pools: resource_pools,
            stemcells: stemcells
          }
        )
      end

      context 'when using stemcells' do
        let(:stemcells) do
          {
            'stemcell-alias' => {
              'alias' => 'stemcell-alias',
              'os' => 'stemcell-os',
              'version' => 'stemcell-version'
            }
          }
        end

        context 'when resource pool is not defined' do
          let(:resource_pools) { {} }

          it 'does not raise' do
              expect{deployment_validator.validate(deployment)}.not_to raise_error
          end
        end

        context 'when resource pool is defined' do
          let(:resource_pools) do
            {'name' => 'resource_pool1'}
          end

          it 'raises an error ' do
            expect { deployment_validator.validate(deployment) }.to raise_error(
                DeploymentInvalidResourceSpecification,
                "'resource_pools' cannot be specified along with 'stemcells'"
              )
          end
        end
      end

      context 'when not using stemcells ' do
        let(:stemcells) { {} }

        context 'when resource pool is not defined' do
          let(:resource_pools) { {} }

          it 'raises' do
            expect{deployment_validator.validate(deployment)}.to raise_error(DeploymentInvalidResourceSpecification,
              "'stemcells' or 'resource_pools' need to be specified"
            )
          end
        end

        context 'when resource pool is defined' do
          let(:resource_pools) do
            {'name' => 'resource_pool1'}
          end

          it 'does not raise' do
            expect{deployment_validator.validate(deployment)}.not_to raise_error
          end
        end
      end
    end
  end
end
