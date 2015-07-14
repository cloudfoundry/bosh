module Support
  module StemcellHelpers
    def make_stemcell
      model = Bosh::Director::Models::Stemcell.make
      deployment = Bosh::Director::Models::Deployment.make
      stemcell = Bosh::Director::DeploymentPlan::Stemcell.new(
        double(:resource_pool, deployment_plan: double(:plan, model: deployment)),
        {'name' => model.name, 'version' => model.version}
      )
      stemcell.bind_model
      stemcell
    end
  end
end
