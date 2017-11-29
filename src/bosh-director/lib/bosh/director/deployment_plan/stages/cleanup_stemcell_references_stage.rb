module Bosh::Director
  module DeploymentPlan
    module Stages
      class CleanupStemcellReferencesStage

        def initialize(deployment_planner)
          @deployment_planner = deployment_planner
        end

        def perform
          current_stemcell_models = @deployment_planner.resource_pools.map { |pool| pool.stemcell.models }.flatten

          @deployment_planner.stemcells.values.map(&:models).flatten.each do |stemcell|
            current_stemcell_models << stemcell
          end

          deployment_plan_model = @deployment_planner.model
          deployment_plan_model.stemcells.each do |deployment_stemcell|
            deployment_stemcell.remove_deployment(deployment_plan_model) unless current_stemcell_models.include?(deployment_stemcell)
          end
        end
      end
    end
  end
end
