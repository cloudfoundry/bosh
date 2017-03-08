module Bosh
  module Director
    module Models
      class RuntimeConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(runtime_config_hash)
          self.properties = YAML.dump(runtime_config_hash)
        end

        def raw_manifest
          YAML.load(properties)
        end

        def interpolated_manifest_for_deployment(deployment_name)
          manifest_hash = YAML.load(properties)
          variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
          variables_interpolator.interpolate_runtime_manifest(manifest_hash, deployment_name)
        end

        def tags(deployment_name)
          interpolated_manifest = interpolated_manifest_for_deployment(deployment_name)
          interpolated_manifest['tags'] ? interpolated_manifest['tags']: {}
        end
      end
    end
  end
end
