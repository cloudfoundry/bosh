module Bosh::Director
  module RuntimeConfig
    class RuntimeManifestResolver

      extend ValidationHelper

      def self.resolve_manifest(raw_runtime_config_hash)
        runtime_config_manifest = Bosh::Common::DeepCopy.copy(raw_runtime_config_hash)

        if Bosh::Director::Config.config_server_enabled
          index_type = Integer

          ignored_subtrees = []
          ignored_subtrees << ['addons', index_type, 'properties']
          ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'properties']
          ignored_subtrees << ['addons', index_type, 'jobs', index_type, 'consumes', String, 'properties']
          runtime_config_manifest = Bosh::Director::ConfigServer::ConfigParser.parse(runtime_config_manifest, ignored_subtrees)
        end
        runtime_config_manifest
      end

    end
  end
end
