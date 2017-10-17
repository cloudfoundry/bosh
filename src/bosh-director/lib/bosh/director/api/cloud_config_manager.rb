module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(cloud_config_yaml)
          cloud_config = Bosh::Director::Models::Config.new(
            type: 'cloud',
            name: 'default',
            content: cloud_config_yaml
          )
          cloud_config.save
        end

        def list(limit)
          Bosh::Director::Models::Config.where(type: 'cloud', name: 'default').order(Sequel.desc(:id)).limit(limit).to_a
        end

        def find_by_id(id)
          Bosh::Director::Models::Config.find(id: id)
        end

        def self.interpolated_manifest(cloud_configs, deployment_name)
          cloud_configs_consolidator = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
          cloud_configs_consolidator.interpolate_manifest_for_deployment(deployment_name)
        end
      end
    end
  end
end
