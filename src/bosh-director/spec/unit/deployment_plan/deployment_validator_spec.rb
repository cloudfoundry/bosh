require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DeploymentValidator do
    describe '#validate' do
      let(:deployment_validator) { DeploymentPlan::DeploymentValidator.new }
      let(:cloud_config) { Models::Config.make(:cloud) }
      let(:deployment_model) {  Bosh::Director::Models::Deployment.make }
      let(:deployment) do
        instance_double(DeploymentPlan::Planner,
          {
            resource_pools: resource_pools,
            stemcells: stemcells,
            model: deployment_model,
            use_dns_addresses?: true
          }
        )
      end

      let(:links_manager) do
        instance_double(Bosh::Director::Links::LinksManager)
      end

      before do
        allow(links_manager).to receive(:resolve_deployment_links).with(deployment_model, anything)
        allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
        allow(deployment).to receive(:is_deploy?).and_return(true)
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

          it 'does not raise an error' do
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

          it 'raises an error' do
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

      context 'when the deployment_planner is not doing a deploy' do
        let(:stemcells) { {} }
        let(:resource_pools) do
          {'name' => 'resource_pool1'}
        end

        it 'should not resolve deployment links' do
          allow(deployment).to receive(:is_deploy?).and_return(false)
          expect(links_manager).to_not receive(:resolve_deployment_links)
          deployment_validator.validate(deployment)
        end
      end

      context 'when link validation fails' do
        let(:stemcells) { {} }
        let(:resource_pools) do
          {'name' => 'resource_pool1'}
        end

        it 'should raise an error' do
          expect(links_manager).to receive(:resolve_deployment_links).with(deployment_model, dry_run: true, global_use_dns_entry: true).and_raise("Link dry run found an error")

          expect{
            deployment_validator.validate(deployment)
          }.to raise_error("Link dry run found an error")
        end
      end
    end
  end
end
