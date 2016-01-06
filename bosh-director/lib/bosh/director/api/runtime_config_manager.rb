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

        private

        def validate_manifest!(runtime_config)
          _ = runtime_config.manifest
        end
      end
    end
  end
end
