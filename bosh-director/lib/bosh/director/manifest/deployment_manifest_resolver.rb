module Bosh::Director
  class DeploymentManifestResolver

    extend ValidationHelper

    # returns a hybrid deployment manifest
    # It will contain uninterpolated properties that will never get resolved
    def self.resolve_manifest(raw_deployment_manifest, resolve_interpolation)
      result_deployment_manifest = Bosh::Common::DeepCopy.copy(raw_deployment_manifest)

      self.inject_uninterpolated_global_properties!(result_deployment_manifest)
      self.inject_instance_group_and_job_uninterpolated_properties_and_env!(result_deployment_manifest)
      self.inject_resource_pool_uninterpolated_env!(result_deployment_manifest)

      if Bosh::Director::Config.config_server_enabled && resolve_interpolation
        index_type = Integer
        
        ignored_subtrees = []
        ignored_subtrees << ['uninterpolated_properties']
        ignored_subtrees << ['instance_groups', index_type, 'uninterpolated_properties']
        ignored_subtrees << ['instance_groups', index_type, 'jobs', index_type, 'uninterpolated_properties']
        ignored_subtrees << ['jobs', index_type, 'uninterpolated_properties']
        ignored_subtrees << ['jobs', index_type, 'templates', index_type, 'uninterpolated_properties']

        ignored_subtrees << ['instance_groups', index_type, 'uninterpolated_env']
        ignored_subtrees << ['jobs', index_type, 'uninterpolated_env']

        ignored_subtrees << ['resource_pools', index_type, 'uninterpolated_env']

        result_deployment_manifest = Bosh::Director::ConfigServer::ConfigParser.parse(result_deployment_manifest, ignored_subtrees)
      end
      result_deployment_manifest
    end

    private


    def self.inject_uninterpolated_global_properties!(deployment_manifest)
      self.copy_properties_to_uninterpolated_properties!(deployment_manifest)
    end

    def self.inject_instance_group_and_job_uninterpolated_properties_and_env!(deployment_manifest)
      outer_key = 'instance_groups'
      inner_key = 'jobs'

      if is_legacy_manifest?(deployment_manifest)
        outer_key = 'jobs'
        inner_key = 'templates'
      end

      instance_groups_list = safe_property(deployment_manifest, outer_key, :class => Array, :default => [])
      instance_groups_list.each do |instance_group_hash|
        self.copy_properties_to_uninterpolated_properties!(instance_group_hash)
        self.copy_env_to_uninterpolated_env!(instance_group_hash)

        jobs_list = safe_property(instance_group_hash, inner_key, :class => Array, :default => [])
        jobs_list.each do |job_hash|
          self.copy_properties_to_uninterpolated_properties!(job_hash)
        end
      end
    end

    def self.inject_resource_pool_uninterpolated_env!(deployment_manifest)
      resource_pool_list = safe_property(deployment_manifest, 'resource_pools', :class => Array, :default => [], optional: true)

      resource_pool_list.each do |resource_pool_hash|
        self.copy_env_to_uninterpolated_env!(resource_pool_hash)
      end
    end

    def self.copy_properties_to_uninterpolated_properties!(generic_hash)
      properties = safe_property(generic_hash, 'properties', :class => Hash, :optional => true)
      if properties
        generic_hash['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(properties)
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
