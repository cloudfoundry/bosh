module Bosh
  module Director
    module Models
      class CloudConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def manifest=(cloud_config_hash)
          self.properties = YAML.dump(cloud_config_hash)
        end

        def manifest
          YAML.load properties
        end
      end
    end
  end
end
