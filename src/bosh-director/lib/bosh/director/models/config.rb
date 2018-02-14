module Bosh
  module Director
    module Models
      class Config < Sequel::Model(Bosh::Director::Config.db)
        def self.check_type(type)
          proc do |_, config|
            raise Bosh::Director::ConfigTypeMismatch, "Expected config type '#{type}', but was '#{config.type}'" unless config.type == type
          end
        end

        def self.latest_set(type)
          find_by_ids(dataset.select { max(:id) }.where(type: type).group_by(:name)).reject(&:deleted)
        end

        def self.dataset_for_teams(*teams)
          dataset.where(Sequel.|({team_id: teams.map(&:id)}, {team_id: nil}))
        end

        def self.latest_set_for_teams(type, *teams)
          latest_config_ids_by_name = dataset_for_teams(*teams).select{ max(:id) }.where({type: type}).group_by(:name)
          find_by_ids(latest_config_ids_by_name).reject(&:deleted)
        end

        def self.find_by_ids(ids)
          dataset.where(id: ids).all
        end

        def self.find_by_ids_for_teams(ids, *teams)
          return [] unless ids
          found = dataset_for_teams(*teams).where(id: ids).all
          raise Sequel::NoMatchingRow, "Failed to find ID: #{(ids - found.map(&:id)).join(', ')}" if found.length != ids.length
          found
        end

        def before_create
          self.created_at ||= Time.now
        end

        def raw_manifest=(config)
          self.content = YAML.dump(config)
        end

        def raw_manifest
          YAML.safe_load(content, [Symbol], [], true)
        end

        def team
          return nil if team_id.nil?
          Team.where(id: team_id).first
        end
      end
    end
  end
end
