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

        def latest
          list(1).first
        end

        def find_by_id(id)
          Bosh::Director::Models::Config.find(id: id)
        end

        def self.interpolated_manifest(cloud_config, deployment_name)
          manifest_hash = YAML.load(cloud_config.content)
          variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
          variables_interpolator.interpolate_cloud_manifest(manifest_hash, deployment_name)
        end
      end
    end
  end
end
