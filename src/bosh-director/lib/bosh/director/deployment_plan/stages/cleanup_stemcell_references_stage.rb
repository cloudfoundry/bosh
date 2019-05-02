module Bosh::Director
  module DeploymentPlan
    module Stages
      class CleanupStemcellReferencesStage
        def initialize(deployment_planner)
          @deployment_planner = deployment_planner
        end

        def perform
          current_stemcell_models = @deployment_planner.stemcells.values.map(&:models).flatten

          deployment_plan_model = @deployment_planner.model

          stemcells_to_remove = []
          deployment_plan_model.stemcells.each do |deployment_stemcell|
            stemcells_to_remove << deployment_stemcell unless current_stemcell_models.include?(deployment_stemcell)
          end

          stemcells_to_remove.each { |stemcell| stemcell.remove_deployment(deployment_plan_model) }
        end
      end
    end
  end
end
