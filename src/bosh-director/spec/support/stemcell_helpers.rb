module Support
  module StemcellHelpers
    def make_stemcell(options = {})
      model = FactoryBot.create(:models_stemcell, options)
      deployment = FactoryBot.create(:models_deployment)

      stemcell = FactoryBot.build(:deployment_plan_stemcell, name: model.name, version: model.version)
      stemcell.bind_model(deployment)
      stemcell
    end
  end
end
