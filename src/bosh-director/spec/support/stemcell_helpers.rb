module Support
  module StemcellHelpers
    def make_stemcell(options = {})
      model = Bosh::Director::Models::Stemcell.make(options)
      deployment = Bosh::Director::Models::Deployment.make

      stemcell = FactoryBot.build(:deployment_plan_stemcell, name: model.name, version: model.version)
      stemcell.bind_model(deployment)
      stemcell
    end
  end
end
