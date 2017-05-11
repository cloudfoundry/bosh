require 'set'

module Bosh::Director
  class Manifest

    def self.load_from_model(deployment_model, options = {})
      manifest_text = deployment_model.manifest || '{}'
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(deployment_model.runtime_configs)
      self.load_manifest(YAML.load(manifest_text), deployment_model.cloud_config, consolidated_runtime_config, options)
    end

    def self.load_from_hash(manifest_hash, cloud_config, runtime_configs, options = {})
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)
      self.load_manifest(manifest_hash, cloud_config, consolidated_runtime_config, options)
    end

    def self.generate_empty_manifest
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new([])
      self.load_manifest({}, nil, consolidated_runtime_config, {:resolve_interpolation => false})
    end

    # hybrid_manifest_hash is a resolved raw_manifest except for properties
    attr_reader :hybrid_manifest_hash
    attr_reader :raw_manifest_hash

    # hybrid_runtime_config_hash a resolved raw_runtime_config_hash except for properties
    attr_reader :hybrid_runtime_config_hash
    # hybrid_cloud_config_hash a resolved raw_cloud_config_hash except for cloud_properties
    attr_reader :hybrid_cloud_config_hash

    def initialize(hybrid_manifest_hash, raw_manifest_hash, hybrid_cloud_config_hash, raw_cloud_config_hash, hybrid_runtime_config_hash, raw_runtime_config_hash)
      @hybrid_manifest_hash = hybrid_manifest_hash
      @raw_manifest_hash = raw_manifest_hash

      @hybrid_cloud_config_hash = hybrid_cloud_config_hash
      @raw_cloud_config_hash = raw_cloud_config_hash

      @hybrid_runtime_config_hash = hybrid_runtime_config_hash
      @raw_runtime_config_hash = raw_runtime_config_hash
    end

    def resolve_aliases
      resolve_aliases_for_generic_hash(to_hash)
      resolve_aliases_for_generic_hash(to_hash({:raw => true}))
    end

    def diff(other_manifest, redact)
      options = { :raw => true }
      Changeset.new(to_hash(options), other_manifest.to_hash(options)).diff(redact).order
    end

    def to_hash(options={})
      raw = options.fetch(:raw, false)
      merge_manifests(
        raw ? @raw_manifest_hash : @hybrid_manifest_hash,
        raw ? @raw_cloud_config_hash : @hybrid_cloud_config_hash,
        raw ? @raw_runtime_config_hash : @hybrid_runtime_config_hash
      )
    end

    private

    def self.load_manifest(manifest_hash, cloud_config, consolidated_runtime_config, options = {})
      resolve_interpolation = options.fetch(:resolve_interpolation, true)
      ignore_cloud_config = options.fetch(:ignore_cloud_config, false)

      cloud_config = nil if ignore_cloud_config

      raw_cloud_config_hash =  cloud_config.raw_manifest unless cloud_config.nil?
      raw_runtime_config_hash = consolidated_runtime_config.raw_manifest

      manifest_hash = manifest_hash.nil? ? {} : manifest_hash

      raw_manifest_hash = Bosh::Common::DeepCopy.copy(manifest_hash)

      if resolve_interpolation
        variables_interpolator = Bosh::Director::ConfigServer::VariablesInterpolator.new
        hybrid_manifest_hash = variables_interpolator.interpolate_deployment_manifest(manifest_hash)
        deployment_name = manifest_hash['name']
        hybrid_cloud_config_hash = cloud_config.interpolated_manifest(deployment_name) unless cloud_config.nil?
        hybrid_runtime_config_hash = consolidated_runtime_config.interpolate_manifest_for_deployment(deployment_name)
      else
        hybrid_manifest_hash = Bosh::Common::DeepCopy.copy(manifest_hash)
        hybrid_cloud_config_hash = Bosh::Common::DeepCopy.copy(raw_cloud_config_hash)
        hybrid_runtime_config_hash = Bosh::Common::DeepCopy.copy(raw_runtime_config_hash)
      end

      new(hybrid_manifest_hash, raw_manifest_hash, hybrid_cloud_config_hash, raw_cloud_config_hash, hybrid_runtime_config_hash, raw_runtime_config_hash)
    end

    def resolve_aliases_for_generic_hash(generic_hash)
      generic_hash['resource_pools'].to_a.each do |rp|
        rp['stemcell']['version'] = resolve_stemcell_version(rp['stemcell'])
      end

      generic_hash['stemcells'].to_a.each do |stemcell|
        stemcell['version'] = resolve_stemcell_version(stemcell)
      end

      generic_hash['releases'].to_a.each do |release|
        release['version'] = resolve_release_version(release)
      end
    end

    def merge_manifests(deployment_manifest, cloud_manifest, runtime_config_manifest)
      hash = deployment_manifest.merge(cloud_manifest || {})
      hash.merge(runtime_config_manifest || {}) do |key, old, new|
        if key == 'releases'
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
