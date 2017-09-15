module Bosh
  module Director
    module Models
      class RuntimeConfig < Sequel::Model(Bosh::Director::Config.db)
        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(runtime_config_hash)
          self.properties = YAML.dump(runtime_config_hash)
        end

        def raw_manifest
          YAML.load(properties)
        end

        def self.latest_set
          self.dataset.where(:id => self.dataset.select{max(:id)}.group_by(:name)).all
        end

        def self.find_by_ids(ids)
          self.dataset.where(:id => ids).all
        end
      end
    end
  end
end
