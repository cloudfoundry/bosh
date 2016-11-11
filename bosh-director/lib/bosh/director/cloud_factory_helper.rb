module Bosh::Director
  module CloudFactoryHelper
    def cloud_factory
      # when the current context has no deployment/cloud config available (i.e. the orphaned disk model)
      # that could be passed to cloud factory, we use the latest cloud config
      CloudFactory.new(CloudFactory.create_cloud_planner(Bosh::Director::Api::CloudConfigManager.new.latest),
                       CloudFactory.parse_cpi_config(Bosh::Director::Api::CpiConfigManager.new.latest))
    end
  end
end
