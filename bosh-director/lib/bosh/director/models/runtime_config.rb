module Bosh
  module Director
    module Models
      class RuntimeConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def manifest=(runtime_config_hash)
          self.properties = Psych.dump(runtime_config_hash)
        end

        def manifest
          Psych.load properties
        end
      end
    end
  end
end
