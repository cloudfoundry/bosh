module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(cloud_config_yaml)
          cloud_config = Bosh::Director::Models::CloudConfig.new(
            properties: cloud_config_yaml
          )
          cloud_config.save
        end
      end
    end
  end
end
