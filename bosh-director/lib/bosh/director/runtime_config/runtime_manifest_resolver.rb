module Bosh::Director
  module RuntimeConfig
    class RuntimeManifestResolver

      extend ValidationHelper

      def self.resolve_manifest(raw_runtime_config_hash)
        runtime_config_manifest = Bosh::Common::DeepCopy.copy(raw_runtime_config_hash)

        config_server_client_factory = Bosh::Director::ConfigServer::ClientFactory.create(Config.logger)
        config_server_client = config_server_client_factory.create_client

        index_type = Integer
        ignored_subtrees = []
        ignored_subtrees << ['addons', index_type, 'properties']
        ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
        ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', String, 'properties']

        runtime_config_manifest = config_server_client.interpolate(runtime_config_manifest, ignored_subtrees)

        runtime_config_manifest
      end

    end
  end
end
