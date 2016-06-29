module Bosh
  module Director
    module Api
      class RuntimeConfigManager
        def update(runtime_config_yaml)
          runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: runtime_config_yaml
          )
          validate_manifest!(runtime_config)
          runtime_config.save
        end

        def list(limit)
          Bosh::Director::Models::RuntimeConfig.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        def find_by_id(id)
          Bosh::Director::Models::RuntimeConfig.find(id: id)
        end

        private

        def validate_manifest!(runtime_config)
          runtime_manifest = runtime_config.manifest
          Bosh::Director::RuntimeConfig::RuntimeManifestParser.new.parse(runtime_manifest)
        end
      end
    end
  end
end
