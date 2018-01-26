module Bosh
  module Director
    module Api
      class ConfigManager
        def create(type, name, config_yaml)
          config = Bosh::Director::Models::Config.new(
              type: type,
              name: name,
              content: config_yaml
          )
          config.save
        end

        def find(type: nil, name: nil, latest: nil)
          dataset = Bosh::Director::Models::Config.where(deleted: false)
          dataset = dataset.where(type: type) if type
          dataset = dataset.where(name: name) if name
          dataset = dataset.where(id: dataset.select{max(:id)}.group(:type, :name)) if latest == 'true'
          dataset
            .order(:type)
            .order_append {Sequel.case([[{name: 'default'}, 1]], 2)}
            .order_append(:name)
            .order_append(Sequel.desc(:id))
            .all
        end

        def find_by_id(id)
          config = Bosh::Director::Models::Config[id]
          if config.nil?
            raise ConfigNotFound, "Config #{id} not found"
          end
          config
        end

        def delete(type, name)
          Bosh::Director::Models::Config
            .where(type: type, name: name, deleted: false)
            .update(deleted: true)
        end
      end
    end
  end
end
