require 'spec_helper'

module Bosh::Director
  module DeploymentPlan::Stages
    describe CleanupStemcellReferencesStage do
      subject { CleanupStemcellReferencesStage.new(deployment_planner) }

      let!(:stemcell_model) { Bosh::Director::Models::Stemcell.make }
      let(:unused_stemcell) { Bosh::Director::Models::Stemcell.make }
      let(:unused_stemcell2) { Bosh::Director::Models::Stemcell.make }
      let(:unused_stemcell3) { Bosh::Director::Models::Stemcell.make }

      let(:deployment_model) { FactoryBot.create(:models_deployment) }
      let(:deployment_planner) { instance_double(DeploymentPlan::Planner) }
      let(:planner_stemcell) do
        FactoryBot.build(:deployment_plan_stemcell, name: stemcell_model.name, version: stemcell_model.version)
      end

      before do
        Bosh::Director::App.new(Bosh::Director::Config.load_hash(SpecHelper.spec_get_director_config))
        allow(deployment_planner).to receive(:model).and_return(deployment_model)

        planner_stemcell.bind_model(deployment_model)
        unused_stemcell.add_deployment(deployment_model)
        unused_stemcell2.add_deployment(deployment_model)
        unused_stemcell3.add_deployment(deployment_model)
      end

      describe '#perform' do
        context 'when using vm types and stemcells' do
          before do
            allow(deployment_planner).to receive(:stemcells).and_return(
              'default' => planner_stemcell,
            )
          end

          context 'when the stemcells associated with the deployment have diverged from those associated with the planner' do
            it 'it removes the given deployment from any stemcell it should not be associated with' do
              expect(stemcell_model.deployments).to include(deployment_model)
              expect(unused_stemcell.deployments).to include(deployment_model)
              expect(unused_stemcell2.deployments).to include(deployment_model)
              expect(unused_stemcell3.deployments).to include(deployment_model)

              subject.perform

              expect(stemcell_model.reload.deployments).to include(deployment_model)
              expect(unused_stemcell.reload.deployments).to_not include(deployment_model)
              expect(unused_stemcell2.reload.deployments).to_not include(deployment_model)
              expect(unused_stemcell3.reload.deployments).to_not include(deployment_model)
            end
          end
        end
      end
    end
  end
end
