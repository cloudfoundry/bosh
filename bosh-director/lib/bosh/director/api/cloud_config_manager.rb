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

        def list(limit)
          Bosh::Director::Models::CloudConfig.order(Sequel.desc(:created_at)).limit(limit).to_a
        end

        def latest
          list(1).first
        end
      end
    end
  end
end
