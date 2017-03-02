module Bosh
  module Director
    module Api
      class TasksConfigManager
        def update(tasks_config_yaml)
          tasks_config = Bosh::Director::Models::TasksConfig.new(
            properties: tasks_config_yaml
          )

          properties = validate_yml(tasks_config_yaml)
          tasks_config.save

          Delayed::Worker.backend = :sequel
          if properties['paused']
            Delayed::Job.filter(:locked_by => nil, :failed_at => nil).exclude(:queue => 'urgent').update(:queue => 'pause')
          else
            Delayed::Job.filter(:queue => 'pause', :locked_by => nil, :failed_at => nil).each do |delayed_job|
              job_class= YAML.load_dj(delayed_job.handler)
              delayed_job.update(:queue => job_class.queue_name)
            end
          end
        end

        def list(limit)
          Bosh::Director::Models::TasksConfig.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        def self.tasks_paused?
          record = Bosh::Director::Models::TasksConfig.order(Sequel.desc(:id)).limit(1).first
          !record.nil? && record.manifest['paused'] == true ? true : false
        end

        private

        def validate_yml(tasks_config)
          properties = YAML.load(tasks_config)
          if properties.nil? || !properties.is_a?(Hash) || !properties.has_key?('paused')
            raise InvalidYamlError, "Incorrect YAML structure of the uploaded manifest"
          end
          properties
        rescue Exception => e
          raise InvalidYamlError, e.message
        end
      end
    end
  end
end
