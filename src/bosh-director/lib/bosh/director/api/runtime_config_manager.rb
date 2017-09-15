module Bosh
  module Director
    module Api
      class RuntimeConfigManager
        def update(runtime_config_yaml, name='')
          runtime_config = Bosh::Director::Models::RuntimeConfig.new(
            properties: runtime_config_yaml,
            name: name,
          )

          validate_yml(runtime_config_yaml)
          runtime_config.save
        end

        def list(limit, name='')
          Bosh::Director::Models::RuntimeConfig.where(name: name).order(Sequel.desc(:id)).limit(limit).to_a
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
