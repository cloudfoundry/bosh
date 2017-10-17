require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentValidator do
    describe '#validate' do
      let(:default_stemcells) do
        {
          'stemcell-alias' => {
            'alias' => 'stemcell-alias',
            'os' => 'stemcell-os',
            'version' => 'stemcell-version'
          }
        }
      end
      let(:default_vm_types) do
        {'name' => 'vm-type1'}
      end

      let(:deployment) { instance_double(DeploymentPlan::Planner, {manifest_hash: manifest_hash, }) }
      let(:deployment_validator) { DeploymentPlan::DeploymentValidator.new }

      let(:cloud_config) { Models::Config.make(:cloud) }

      context 'when using stemcells and vm_types' do
        let(:deployment) do
          instance_double(DeploymentPlan::Planner,
            {
              resource_pools: resource_pools,
              stemcells: stemcells,
              vm_types: vm_types
            }
          )
        end

        context 'when both are specified inside deployment' do
          let(:stemcells) { default_stemcells }
          let(:vm_types) { default_vm_types }
          let(:resource_pools) { {} }

          it 'does not raise' do
            expect{deployment_validator.validate(deployment)}.not_to raise_error
          end
        end

        context 'when resource pool is defined' do
          let(:stemcells) { default_stemcells }
          let(:vm_types) { default_vm_types }
          let(:resource_pools) do
            {'name' => 'resource_pool1'}
          end

          it 'raises an error ' do
            expect { deployment_validator.validate(deployment) }.to raise_error(
                DeploymentInvalidResourceSpecification,
                "'resource_pools' cannot be specified along with 'stemcells' and/or 'vm_types'"
              )
          end
        end

        context 'raises an error when stemcells are undefined' do
          let(:stemcells) { {} }
          let(:vm_types) { default_vm_types }
          let(:resource_pools) { {} }

          it 'raises an error ' do
            expect { deployment_validator.validate(deployment) }.to raise_error(
                DeploymentInvalidResourceSpecification,
                "Both 'stemcells' and 'vm_types' need to be specified: 'stemcells' is missing"
              )
          end
        end
        context 'raises an error when vm_types undefined' do
          let(:stemcells) { default_stemcells }
          let(:vm_types) { {} }
          let(:resource_pools) { {} }

          it 'raises an error ' do
            expect { deployment_validator.validate(deployment) }.to raise_error(
                DeploymentInvalidResourceSpecification,
                "Both 'stemcells' and 'vm_types' need to be specified: 'vm_types' is missing"
              )
          end
        end
      end
    end
  end
end
