module Bosh::Director
  module RuntimeConfig
    class RuntimeConfigsConsolidator
      include ValidationHelper

      attr_reader :runtime_configs

      def self.create_from_model_ids(runtime_configs_ids)
        new(Bosh::Director::Models::RuntimeConfig.find_by_ids(runtime_configs_ids))
      end

      def initialize(runtime_configs)
        @runtime_configs = runtime_configs
        @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
      end

      def raw_manifest
        @consolidated_raw_manifest ||= merge_manifests
      end

      def have_runtime_configs?
        !@runtime_configs.empty?
      end

      def interpolate_manifest_for_deployment(deployment_name)
        @variables_interpolator.interpolate_runtime_manifest(raw_manifest, deployment_name)
      end

      def tags(deployment_name)
        interpolated_hash = interpolate_manifest_for_deployment(deployment_name)

        interpolated_hash['tags'] || {}
      end

      private

      def merge_manifests
        return {} if @runtime_configs.empty?

        result_hash = {
          'releases' => [],
          'addons' => [],
        }

        @runtime_configs.each do |runtime_config|
          manifest_hash = runtime_config.raw_manifest
          result_hash['releases'] += safe_property(manifest_hash, 'releases', :class => Array, :default => [])
          result_hash['addons'] += safe_property(manifest_hash, 'addons', :class => Array, :default => [])

          tags = safe_property(manifest_hash, 'tags', :class => Hash, :optional => true)
          if tags && result_hash['tags']
            raise RuntimeConfigParseError, "Runtime config 'tags' key cannot be defined in multiple runtime configs."
          end

          result_hash['tags'] = tags unless tags.nil?

        end

        result_hash
      end

    end
  end
end
