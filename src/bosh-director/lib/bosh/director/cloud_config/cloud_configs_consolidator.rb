module Bosh::Director
  module CloudConfig
    class CloudConfigsConsolidator
      include ValidationHelper

      attr_reader :cloud_configs

      def self.create_from_model_ids(cloud_configs_ids)
        new(Bosh::Director::Models::Config.find_by_ids(cloud_configs_ids))
      end

      def initialize(cloud_configs)
        @cloud_configs = cloud_configs || []
        @variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
      end

      def raw_manifest
        @consolidated_raw_manifest ||= merge_manifests
      end

      def self.have_cloud_configs?(cloud_configs)
        return false if cloud_configs.empty?

        cloud_configs.each do |cc|
          return true unless cc.raw_manifest.empty?
        end

        return false
      end

      def interpolate_manifest_for_deployment(deployment_name)
        interpolated_manifest = @variables_interpolator.interpolate_cloud_manifest(raw_manifest, deployment_name)
        interpolated_manifest.each_value do |v|
          if v.kind_of?(Array)
            v.flatten!(1)
          end
        end
      end

      private

      def merge_manifests
        return {} unless self.class.have_cloud_configs?(@cloud_configs)

        result_hash = {}
        keys = ['azs', 'vm_types', 'disk_types', 'networks', 'vm_extensions']
        keys.each do |key|
          result_hash[key] = []
        end

        @cloud_configs.each do |cloud_config|
          manifest_hash = cloud_config.raw_manifest || {}
          keys.each do |key|
            if ConfigServer::ConfigServerHelper.is_full_variable? manifest_hash[key]
              result_hash[key] << manifest_hash[key]
            else
              result_hash[key] += safe_property(manifest_hash, key, :class => Array, :default => [])
            end
          end

          compilation = safe_property(manifest_hash, 'compilation', :class => Hash, :optional => true)
          if compilation && result_hash['compilation']
            raise CloudConfigMergeError, "Cloud config 'compilation' key cannot be defined in multiple cloud configs."
          end
          result_hash['compilation'] = compilation unless compilation.nil?
        end

        result_hash
      end

    end
  end
end
