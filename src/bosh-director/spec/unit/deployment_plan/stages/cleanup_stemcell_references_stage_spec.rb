require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Stages
    describe CleanupStemcellReferencesStage do
      subject { CleanupStemcellReferencesStage.new(deployment_planner) }

      let!(:stemcell_model) { Bosh::Director::Models::Stemcell.create(name: 'default', version: '1', cid: 'abc') }
      let(:stemcell_model_2) { Bosh::Director::Models::Stemcell.create(name: 'stem2', version: '1.0', cid: 'def') }
      let(:deployment_model) { Models::Deployment.make }
      let(:deployment_planner) { instance_double(DeploymentPlan::Planner) }
      let(:planner_stemcell) {
        DeploymentPlan::Stemcell.parse({
          'alias' => 'default',
          'name' => 'default',
          'version' => '1',
        })
      }

      before do

        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
        allow(deployment_planner).to receive(:model).and_return(deployment_model)

        allow(deployment_planner).to receive(:resource_pools).and_return([])

        planner_stemcell.bind_model(deployment_model)
        stemcell_model_2.add_deployment(deployment_model)
      end


      describe '#perform' do

        context 'when using resource pools' do
          context "when the stemcells associated with the resource pools have diverged from the stemcells associated with the planner" do
            let(:resource_pool) { DeploymentPlan::ResourcePool.new(resource_pool_spec) }
            let(:resource_pool_spec) do
              {
                'name' => 'default',
                'cloud_properties' => {},
                'network' => 'default',
                'stemcell' => {
                  'name' => 'default',
                  'version' => '1'
                }
              }
            end

            before do
              resource_pool.stemcell.bind_model(deployment_model)
              allow(deployment_planner).to receive(:resource_pools).and_return([resource_pool])
              allow(deployment_planner).to receive(:stemcells).and_return({})
            end

            it 'it removes the given deployment from any stemcell it should not be associated with' do
              expect(stemcell_model.deployments).to include(deployment_model)
              expect(stemcell_model_2.deployments).to include(deployment_model)

              subject.perform

              expect(stemcell_model.reload.deployments).to include(deployment_model)
              expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
            end
          end
        end

        context 'when using vm types and stemcells' do
          let(:resource_pools) { [] }

          before do
            allow(deployment_planner).to receive(:stemcells).and_return({
              'default' => planner_stemcell,
            })
          end

          context "when the stemcells associated with the deployment stemcell has diverged from the stemcells associated with the planner" do
            it 'it removes the given deployment from any stemcell it should not be associated with' do
              expect(stemcell_model.deployments).to include(deployment_model)
              expect(stemcell_model_2.deployments).to include(deployment_model)

              subject.perform

              expect(stemcell_model.reload.deployments).to include(deployment_model)
              expect(stemcell_model_2.reload.deployments).to_not include(deployment_model)
            end
          end
        end

      end
    end
  end
end
