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
          find_by_ids(dataset.select{max(:id)}.where(:type => type).group_by(:name)).reject(&:deleted)
        end

        def self.find_by_ids(ids)
          dataset.where(:id => ids).all
        end

        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(config)
          self.content = YAML.dump(config)
        end

        def raw_manifest
          YAML.load content
        end

        def teams
          return [] if self.team_id.nil?
          Team.where(id: [self.team_id]).all
        end
      end
    end
  end
end
