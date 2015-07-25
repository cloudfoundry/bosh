module Support
  module StemcellHelpers
    def make_stemcell
      model = Bosh::Director::Models::Stemcell.make
      deployment = Bosh::Director::Models::Deployment.make
      plan = double(:plan, model: deployment)
      stemcell = Bosh::Director::DeploymentPlan::Stemcell.new(
        {'name' => model.name, 'version' => model.version}
      )
      stemcell.bind_model(plan)
      stemcell
    end
  end
end
