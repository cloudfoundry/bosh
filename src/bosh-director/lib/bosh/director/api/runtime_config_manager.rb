module Bosh
  module Director
    module Api
      class RuntimeConfigManager
        def update(runtime_config_yaml, name='default')
          runtime_config = Bosh::Director::Models::Config.new(
            type: 'runtime',
            content: runtime_config_yaml,
            name: name
          )

          validate_yml(runtime_config_yaml)
          runtime_config.save
        end

        def list(limit, name='default')
          Bosh::Director::Models::Config.where(name: name, type: 'runtime').order(Sequel.desc(:id)).limit(limit).to_a
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
