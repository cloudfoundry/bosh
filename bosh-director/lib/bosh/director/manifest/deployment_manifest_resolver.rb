module Bosh::Director
  class DeploymentManifestResolver

    extend ValidationHelper

    # returns a hybrid deployment manifest
    # It will contain uninterpolated properties that will never get resolved
    def self.resolve_manifest(raw_deployment_manifest, resolve_interpolation)
      result_deployment_manifest = Bosh::Common::DeepCopy.copy(raw_deployment_manifest)

      self.inject_instance_group_uninterpolated_env!(result_deployment_manifest)
      self.inject_resource_pool_uninterpolated_env!(result_deployment_manifest)

      if Bosh::Director::Config.config_server_enabled && resolve_interpolation
        index_type = Integer
        any_string = String
        
        ignored_subtrees = []
        ignored_subtrees << ['properties']
        ignored_subtrees << ['instance_groups', index_type, 'properties']
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'properties']
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'consumes', any_string, 'properties']
        ignored_subtrees << ['jobs', index_type, 'properties']
        ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'properties']
        ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'consumes', any_string, 'properties']

        ignored_subtrees << ['instance_groups', index_type, 'uninterpolated_env']
        ignored_subtrees << ['jobs', index_type, 'uninterpolated_env']

        ignored_subtrees << ['resource_pools', index_type, 'uninterpolated_env']

        result_deployment_manifest = Bosh::Director::ConfigServer::ConfigParser.parse(result_deployment_manifest, ignored_subtrees)
      end
      result_deployment_manifest
    end

    private

    def self.inject_instance_group_uninterpolated_env!(deployment_manifest)
      outer_key = is_legacy_manifest?(deployment_manifest) ? 'jobs' : 'instance_groups'

      instance_groups_list = safe_property(deployment_manifest, outer_key, :class => Array, :default => [])
      instance_groups_list.each do |instance_group_hash|
        self.copy_env_to_uninterpolated_env!(instance_group_hash)
      end
    end

    def self.inject_resource_pool_uninterpolated_env!(deployment_manifest)
      resource_pool_list = safe_property(deployment_manifest, 'resource_pools', :class => Array, :default => [], optional: true)

      resource_pool_list.each do |resource_pool_hash|
        self.copy_env_to_uninterpolated_env!(resource_pool_hash)
      end
    end

    def self.copy_env_to_uninterpolated_env!(generic_hash)
      env = safe_property(generic_hash, 'env', :class => Hash, :optional => true)
      if env
        generic_hash['uninterpolated_env'] = Bosh::Common::DeepCopy.copy(env)
      end
    end

    def self.is_legacy_manifest?(deployment_manifest)
      deployment_manifest['instance_groups'].nil?
    end
  end
end
