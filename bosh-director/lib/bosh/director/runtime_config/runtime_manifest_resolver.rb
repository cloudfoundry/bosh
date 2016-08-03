module Bosh::Director
  module RuntimeConfig
    class RuntimeManifestResolver

      extend ValidationHelper

      def self.resolve_manifest(raw_runtime_config_hash)
        runtime_config_manifest = Bosh::Common::DeepCopy.copy(raw_runtime_config_hash)
        inject_uninterpolated_properties!(runtime_config_manifest)

        if Bosh::Director::Config.config_server_enabled
          ignored_subtrees = []
          ignored_subtrees << ['addons', Numeric.new, 'uninterpolated_properties']
          ignored_subtrees << ['addons', Numeric.new, 'jobs', Numeric.new, 'uninterpolated_properties']
          runtime_config_manifest = Bosh::Director::ConfigServer::ConfigParser.parse(runtime_config_manifest, ignored_subtrees)
        end
        runtime_config_manifest
      end

      private

      def self.inject_uninterpolated_properties!(runtime_config_hash)
        addons_list = safe_property(runtime_config_hash, 'addons', :class => Array, :default => [])
        addons_list.each do |addon_hash|
          copy_properties_to_uninterpolated_properties!(addon_hash)

          jobs_list = safe_property(addon_hash, 'jobs', :class => Array, :default => [])
          jobs_list.each do |job_hash|
            copy_properties_to_uninterpolated_properties!(job_hash)
          end
        end
      end

      def self.copy_properties_to_uninterpolated_properties!(generic_hash)
        properties = safe_property(generic_hash, 'properties', :class => Hash, :default => nil)
        if properties
          generic_hash['uninterpolated_properties'] = Bosh::Common::DeepCopy.copy(properties)
        end
      end
    end
  end
end
