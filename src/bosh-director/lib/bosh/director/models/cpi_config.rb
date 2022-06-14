module Bosh
  module Director
    module Models
      class CpiConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def manifest=(cpi_config_hash)
          self.properties = YAML.dump(cpi_config_hash)
        end

        def manifest
          YAML.load(properties, aliases: true)
        end
      end
    end
  end
end

