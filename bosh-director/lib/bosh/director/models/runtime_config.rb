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

          if Bosh::Director::Config.config_server_enabled
            Bosh::Director::ConfigServer::ConfigParser.new(manifest_hash).parsed
          else
            manifest_hash
          end
        end
      end
    end
  end
end
