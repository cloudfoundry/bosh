module Bosh::Director::Models
  class Deployment < Sequel::Model(Bosh::Director::Config.db)

    def self.join_table_block(type)
      lambda do |ds|
        ds.where(config_id: self.db[:configs].select(:id).where(type: type))
      end
    end

    many_to_many :networks, class: 'Bosh::Director::Models::Network', join_table: :deployments_networks
    many_to_many :stemcells, order: [Sequel.asc(:name), Sequel.asc(:version)]
    many_to_many :release_versions
    one_to_many  :job_instances, :class => 'Bosh::Director::Models::Instance'
    one_to_many  :instances
    one_to_many  :dynamic_disks
    one_to_many  :properties, :class => "Bosh::Director::Models::DeploymentProperty"
    one_to_many  :problems, :class => "Bosh::Director::Models::DeploymentProblem"
    one_to_many  :link_consumers, :class => 'Bosh::Director::Models::Links::LinkConsumer'
    one_to_many  :link_providers, :class => 'Bosh::Director::Models::Links::LinkProvider'
    one_to_many  :properties, :class => 'Bosh::Director::Models::DeploymentProperty'
    one_to_many  :problems, :class => 'Bosh::Director::Models::DeploymentProblem'
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
    many_to_many :teams, order: Sequel.asc(:name)
    one_to_many  :variable_sets, :class => 'Bosh::Director::Models::VariableSet'

    def validate
      validates_presence :name
      validates_unique :name
      validates_format VALID_ID, :name
    end

    def self.create_with_teams(attributes)
      teams = attributes.delete(:teams)
      runtime_configs = attributes.delete(:runtime_configs)
      cloud_configs = attributes.delete(:cloud_configs)

      deployment = create(attributes)

      deployment.teams = teams
      deployment.runtime_configs = runtime_configs
      deployment.cloud_configs = cloud_configs
      deployment
    end

    def cloud_configs=(cloud_configs)
      with_raise_first_failure do
        remove_all_cloud_configs
        (cloud_configs || []).each do |cc|
          add_cloud_config(cc)
        end
      end
    end

    def runtime_configs=(runtime_configs)
      with_raise_first_failure do
        remove_all_runtime_configs
        (runtime_configs || []).each do |rc|
          add_runtime_config(rc)
        end
      end
    end

    def teams=(teams)
      with_raise_first_failure do
        remove_all_teams
        (teams || []).each do |t|
          add_team(t)
        end
      end
    end

    def tags
      return {} unless manifest

      manifest_tags = YAML.load(manifest, aliases: true)['tags']

      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)

      manifest_tags ||= {}

      variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new

      return {} unless current_variable_set

      manifest_tags = variables_interpolator.interpolate_with_versioning(manifest_tags, current_variable_set)
      consolidated_runtime_config.tags(name).merge(manifest_tags)
    end

    def current_variable_set
      variable_sets_dataset.order(Sequel.desc(:created_at)).limit(1).first
    end

    def previous_variable_set
      variable_sets_dataset.order(Sequel.desc(:created_at)).limit(2, 1).first
    end

    def last_successful_variable_set
      variable_sets_dataset.where(deployed_successfully: true).order(Sequel.desc(:created_at)).limit(1).first
    end

    def cleanup_variable_sets(variable_sets_to_keep)
      variable_sets_dataset.exclude(:id => variable_sets_to_keep.map(&:id)).delete
    end

    private

    def with_raise_first_failure
      first_exception = nil

      Bosh::Director::Transactor.new.retryable_transaction(db) do |_, exception|
        first_exception = exception if first_exception.nil? && exception

        yield
      end
    rescue Exception => exception
      raise first_exception || exception
    end
  end

  Deployment.plugin :association_dependencies
  Deployment.add_association_dependencies :stemcells => :nullify, :problems => :destroy
  Deployment.many_to_many :variables, :join_table=>:variable_sets, :right_key=>:id,  :right_primary_key=>:variable_set_id
end
