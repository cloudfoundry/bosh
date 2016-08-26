module Bosh::Director
  class DeploymentManifestResolver

    extend ValidationHelper

    # returns a hybrid deployment manifest where properties and env are not interpolated
    def self.resolve_manifest(raw_deployment_manifest)
      config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(Config.logger)
      config_server_client = config_server_client_factory.create_client

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

      config_server_client.interpolate(raw_deployment_manifest, ignored_subtrees)
    end
  end
end
