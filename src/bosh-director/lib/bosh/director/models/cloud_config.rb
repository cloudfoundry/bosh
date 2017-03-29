module Bosh
  module Director
    module Models
      class CloudConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(cloud_config_hash)
          self.properties = YAML.dump(cloud_config_hash)
        end

        def raw_manifest
          YAML.load properties
        end

        def interpolated_manifest(deployment_name)
          manifest_hash = YAML.load(properties)
          variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
          variables_interpolator.interpolate_cloud_manifest(manifest_hash, deployment_name)
        end
      end
    end
  end
end
