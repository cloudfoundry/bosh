module Bosh::Director
  class DeploymentManifestResolver

    extend ValidationHelper

    # returns a hybrid deployment manifest where properties and env are not interpolated
    def self.resolve_manifest(raw_deployment_manifest, resolve_interpolation)
      result_deployment_manifest = Bosh::Common::DeepCopy.copy(raw_deployment_manifest)

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

        ignored_subtrees << ['instance_groups', index_type, 'env']
        ignored_subtrees << ['jobs', index_type, 'env']
        ignored_subtrees << ['resource_pools', index_type, 'env']

        result_deployment_manifest = Bosh::Director::ConfigServer::ConfigParser.parse(result_deployment_manifest, ignored_subtrees)
      end
      result_deployment_manifest
    end
  end
end
