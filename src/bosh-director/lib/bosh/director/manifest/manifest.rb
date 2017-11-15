require 'set'

module Bosh::Director
  class Manifest
    def self.load_from_model(deployment_model, options = {})
      manifest = deployment_model.manifest || '{}'
      manifest_text = deployment_model.manifest_text || '{}'
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(deployment_model.runtime_configs)
      consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(deployment_model.cloud_configs)
      load_manifest(YAML.safe_load(manifest, [Symbol], [], true), manifest_text, consolidated_cloud_config, consolidated_runtime_config, options)
    end

    def self.load_from_hash(manifest_hash, manifest_text, cloud_configs, runtime_configs, options = {})
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)
      consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
      load_manifest(manifest_hash, manifest_text, consolidated_cloud_config, consolidated_runtime_config, options)
    end

    def self.generate_empty_manifest
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new([])
      load_manifest({}, '{}', nil, consolidated_runtime_config, resolve_interpolation: false)
    end

    attr_reader :manifest_hash
    attr_reader :cloud_config_hash
    attr_reader :runtime_config_hash
    attr_reader :manifest_text

    def initialize(manifest_hash, manifest_text, cloud_config_hash, runtime_config_hash)
      @manifest_hash = manifest_hash
      @cloud_config_hash = cloud_config_hash
      @runtime_config_hash = runtime_config_hash
      @manifest_text = manifest_text
    end

    def resolve_aliases
      resolve_aliases_for_generic_hash(to_hash)
    end

    def diff(other_manifest, redact)
      Changeset.new(to_hash, other_manifest.to_hash).diff(redact).order
    end

    def to_hash
      merge_manifests(@manifest_hash, @cloud_config_hash, @runtime_config_hash)
    end

    private

    def self.load_manifest(manifest_hash, manifest_text, cloud_config, runtime_config, options = {})
      resolve_interpolation = options.fetch(:resolve_interpolation, true)
      ignore_cloud_config = options.fetch(:ignore_cloud_config, false)

      cloud_config = nil if ignore_cloud_config

      cloud_config_hash = cloud_config.raw_manifest if cloud_config
      runtime_config_hash = runtime_config.raw_manifest

      manifest_hash = manifest_hash.nil? ? {} : manifest_hash

      manifest_hash = Bosh::Common::DeepCopy.copy(manifest_hash)

      if resolve_interpolation
        variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
        manifest_hash = variables_interpolator.interpolate_deployment_manifest(manifest_hash)
        deployment_name = manifest_hash['name']
        if cloud_config
          cloud_config_hash = cloud_config.interpolate_manifest_for_deployment(deployment_name)
        end
        runtime_config_hash = runtime_config.interpolate_manifest_for_deployment(deployment_name)
      end

      new(manifest_hash, manifest_text, cloud_config_hash, runtime_config_hash)
    end

    def resolve_aliases_for_generic_hash(generic_hash)
      unless generic_hash['resource_pools'].is_a?(String)
        generic_hash['resource_pools'].to_a.each do |rp|
          if rp.is_a?(Hash)
            rp['stemcell']['version'] = resolve_stemcell_version(rp['stemcell'])
          end
        end
      end

      unless generic_hash['stemcells'].is_a?(String)
        generic_hash['stemcells'].to_a.each do |stemcell|
          if stemcell.is_a?(Hash)
            stemcell['version'] = resolve_stemcell_version(stemcell)
          end
        end
      end

      unless generic_hash['releases'].is_a?(String)
        generic_hash['releases'].to_a.each do |release|
          if release.is_a?(Hash)
            release['version'] = resolve_release_version(release)
          end
        end
      end
    end

    def merge_manifests(deployment_manifest, cloud_manifest, runtime_config_manifest)
      hash = deployment_manifest.merge(cloud_manifest || {})
      hash.merge(runtime_config_manifest || {}) do |key, old, new|
        if (key == 'releases') || (key == 'variables')
          if old && new
            old.to_set.merge(new.to_set).to_a
          else
            old.nil? ? new : old
          end
        else
          new
        end
      end
    end

    def resolve_stemcell_version(stemcell)
      stemcell_manager = Api::StemcellManager.new

      unless stemcell.is_a?(Hash)
        raise 'Invalid stemcell spec in the deployment manifest'
      end

      resolvable_version = match_resolvable_version(stemcell['version'])

      if resolvable_version
        if stemcell['os']
          latest_stemcell = stemcell_manager.latest_by_os(stemcell['os'], resolvable_version[:prefix])
        elsif stemcell['name']
          latest_stemcell = stemcell_manager.latest_by_name(stemcell['name'], resolvable_version[:prefix])
        else
          raise 'Stemcell definition must contain either name or os'
        end
        return latest_stemcell[:version].to_s
      end

      stemcell['version'].to_s
    end

    def resolve_release_version(release_def)
      release_manager = Api::ReleaseManager.new
      resolvable_version = match_resolvable_version(release_def['version'])
      if resolvable_version
        release = release_manager.find_by_name(release_def['name'])
        return release_manager.sorted_release_versions(release, resolvable_version[:prefix]).last['version']
      end

      release_def['version'].to_s
    end

    def match_resolvable_version(version)
      /(^|(?<prefix>.+)\.)latest$/.match(version.to_s)
    end
  end
end
