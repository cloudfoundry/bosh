module Bosh
  module Director
    module Models
      class RuntimeConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def manifest=(runtime_config_hash)
          self.properties = YAML.dump(runtime_config_hash)
        end

        def manifest
          manifest_hash = YAML.load(properties)
          config_server_client = Bosh::Director::ConfigServer::ClientFactory.create(Config.logger).create_client
          config_server_client.interpolate_runtime_manifest(manifest_hash)
        end

        def raw_manifest
          YAML.load(properties)
        end

        def tags
          manifest['tags'] ? manifest['tags']: {}
        end
      end
    end
  end
end
