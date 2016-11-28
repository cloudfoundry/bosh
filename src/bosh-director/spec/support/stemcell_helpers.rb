module Support
  module StemcellHelpers
    def make_stemcell(options = {})
      model = Bosh::Director::Models::Stemcell.make(options)
      deployment = Bosh::Director::Models::Deployment.make
      stemcell = Bosh::Director::DeploymentPlan::Stemcell.parse(
        {'name' => model.name, 'version' => model.version}
      )
      stemcell.bind_model(deployment)
      stemcell
    end
  end
end
