module Bosh
  module Director
    module Models
      class Config < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(config_yaml)
          self.content = YAML.dump(config_yaml)
        end

        def raw_manifest
          YAML.load content
        end
      end
    end
  end
end
