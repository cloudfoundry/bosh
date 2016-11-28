module Bosh::Director::Models
  class Deployment < Sequel::Model(Bosh::Director::Config.db)
    many_to_many :stemcells
    many_to_many :release_versions
    one_to_many  :job_instances, :class => "Bosh::Director::Models::Instance"
    one_to_many  :instances
    one_to_many  :properties, :class => "Bosh::Director::Models::DeploymentProperty"
    one_to_many  :problems, :class => "Bosh::Director::Models::DeploymentProblem"
    many_to_one  :cloud_config
    many_to_one  :runtime_config
    many_to_many :teams

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
      deployment = create(attributes)
      deployment.teams = teams
      deployment
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
      tags = {}

      if manifest
        tags = YAML.load(manifest)['tags'] || {}
      end

      tags
    end
  end

  Deployment.plugin :association_dependencies
  Deployment.add_association_dependencies :stemcells => :nullify, :problems => :destroy
end
