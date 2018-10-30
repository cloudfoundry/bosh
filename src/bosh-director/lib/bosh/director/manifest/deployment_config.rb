module Bosh::Director
  class DeploymentConfig
    def initialize(manifest_hash, team_names)
      @manifest_hash = manifest_hash
      @team_names = team_names
      @instance_groups = parse_instance_groups
    end

    def name
      @manifest_hash["name"] || ""
    end

    def team_names
      @team_names
    end

    def instance_groups
      @instance_groups
    end

    def has_releases?
      @manifest_hash.key?('releases') && !@manifest_hash['releases'].empty?
    end

    def manifest_hash
      @manifest_hash
    end

    private

    def parse_instance_groups
      return [] if !@manifest_hash.key?('instance_groups') || !@manifest_hash['instance_groups']

      @manifest_hash['instance_groups'].map do |instance_group|
        Bosh::Director::InstanceGroupConfig.new(instance_group, @manifest_hash['stemcells'])
      end
    end
  end
end
