module Bosh::Director::Models
  class Deployment < Sequel::Model(Bosh::Director::Config.db)

    def self.join_table_block(type)
      lambda do |ds|
        ds.where(config_id: self.db[:configs].select(:id).where(type: type))
      end
    end

    many_to_many :stemcells
    many_to_many :release_versions
    one_to_many  :job_instances, :class => "Bosh::Director::Models::Instance"
    one_to_many  :instances
    one_to_many  :properties, :class => "Bosh::Director::Models::DeploymentProperty"
    one_to_many  :problems, :class => "Bosh::Director::Models::DeploymentProblem"
    many_to_many  :cloud_configs,
      class: Bosh::Director::Models::Config,
      join_table: :deployments_configs,
      right_key: :config_id,
      conditions: {type: 'cloud'},
      before_add: Config.check_type('cloud'),
      before_remove: Config.check_type('cloud'),
      join_table_block: Deployment.join_table_block('cloud')
    many_to_many :runtime_configs,
      class: Bosh::Director::Models::Config,
      join_table: :deployments_configs,
      right_key: :config_id,
      conditions: {type: 'runtime'},
      before_add: Config.check_type('runtime'),
      before_remove: Config.check_type('runtime'),
      join_table_block: Deployment.join_table_block('runtime')
    many_to_many :teams
    one_to_many  :variable_sets, :class => 'Bosh::Director::Models::VariableSet'

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end

    def link_spec
      result = self.link_spec_json
      result ? JSON.parse(result) : {}
    end

    def link_spec=(data)
      self.link_spec_json = JSON.generate(data)
    end

    def self.create_with_teams(attributes)
      teams = attributes.delete(:teams)
      runtime_configs = attributes.delete(:runtime_configs)
      cloud_config = attributes.delete(:cloud_config)

      deployment = create(attributes)

      deployment.teams = teams
      deployment.runtime_configs = runtime_configs
      deployment.cloud_config = cloud_config
      deployment
    end

    def cloud_config
      cloud_configs[0]
    end

    def cloud_config=(cloud_config)
      if cloud_config.nil?
        self.cloud_configs = []
      else
        self.cloud_configs = [cloud_config]
      end
    end

    def cloud_configs=(cloud_configs)
      Bosh::Director::Transactor.new.retryable_transaction(Deployment.db) do
        self.remove_all_cloud_configs
        (cloud_configs || []).each do |cc|
          self.add_cloud_config(cc)
        end
      end
    end

    def runtime_configs=(runtime_configs)
      Bosh::Director::Transactor.new.retryable_transaction(Deployment.db) do
        self.remove_all_runtime_configs
        (runtime_configs || []).each do |rc|
          self.add_runtime_config(rc)
        end
      end
    end

    def teams=(teams)
      Bosh::Director::Transactor.new.retryable_transaction(Deployment.db) do
        self.remove_all_teams
        (teams || []).each do |t|
          self.add_team(t)
        end
      end
    end

    def tags
      return {} unless manifest

      tags = YAML.load(manifest)['tags']
      return {} if tags.nil? || tags.empty?

      client = Bosh::Director::ConfigServer::ClientFactory.create(Bosh::Director::Config.logger).create_client
      client.interpolate_with_versioning(tags, current_variable_set)
    end

    def current_variable_set
      variable_sets_dataset.order(Sequel.desc(:created_at)).limit(1).first
    end

    def last_successful_variable_set
      variable_sets_dataset.where(deployed_successfully: true).order(Sequel.desc(:created_at)).limit(1).first
    end

    def cleanup_variable_sets(variable_sets_to_keep)
      variable_sets_dataset.exclude(:id => variable_sets_to_keep.map(&:id)).delete
    end
  end

  Deployment.plugin :association_dependencies
  Deployment.add_association_dependencies :stemcells => :nullify, :problems => :destroy
  Deployment.many_to_many :variables, :join_table=>:variable_sets, :right_key=>:id,  :right_primary_key=>:variable_set_id
end
