module Bosh
  module Director
    module Api
      class RuntimeConfigManager
        def update(runtime_config_yaml)
          runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: runtime_config_yaml
          )

          validate_yml(runtime_config_yaml)
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

        def validate_yml(runtime_config)
          YAML.load(runtime_config)
        rescue Exception => e
          raise InvalidYamlError, e.message
        end
      end
    end
  end
end
