module Bosh
  module Director
    module Api
      class CloudConfigManager
        def update(cloud_config_yaml, name='default')
          cloud_config = Bosh::Director::Models::Config.new(
            type: 'cloud',
            content: cloud_config_yaml,
            name: name,
          )
          cloud_config.save
        end

        def list(limit, name='default')
          Bosh::Director::Models::Config.where(deleted: false, type: 'cloud', name: name).order(Sequel.desc(:id)).limit(limit).to_a
        end

        def self.interpolated_manifest(cloud_configs, deployment_name)
          cloud_configs_consolidator = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
          cloud_configs_consolidator.interpolate_manifest_for_deployment(deployment_name)
        end
      end
    end
  end
end
