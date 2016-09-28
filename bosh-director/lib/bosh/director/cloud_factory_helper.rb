module Bosh::Director
  module CloudFactoryHelper
    def cloud_factory(deployment)
      CloudFactory.create_from_deployment(deployment)
    end

    def cloud_factory_for_latest_cloud_config
      # when the current context has no deployment/cloud config available (i.e. the orphaned disk model)
      # that could be passed to cloud factory, we use the latest cloud config
      CloudFactory.new(CloudFactory.create_cloud_planner(Bosh::Director::Api::CloudConfigManager.new.latest),
                       CloudFactory.parse_cpi_config(Bosh::Director::Api::CpiConfigManager.new.latest),
                       Config.cloud)
    end
  end
end