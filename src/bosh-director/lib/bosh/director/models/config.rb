module Bosh
  module Director
    module Models
      class Config < Sequel::Model(Bosh::Director::Config.db)

        def self.check_type(type)
          Proc.new do | _, config |
            raise Bosh::Director::ConfigTypeMismatch, "Expected config type '#{type}', but was '#{config.type}'" unless config.type == type
          end
        end

        def self.latest_set(type)
          self.dataset.where(:id => self.dataset.select{max(:id)}.where(:type => type).group_by(:name)).all
        end

        def self.find_by_ids(ids)
          self.dataset.where(:id => ids).all
        end

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
