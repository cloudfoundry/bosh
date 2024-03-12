require 'set'

module Bosh::Director
  class Manifest
    def self.load_from_model(deployment_model, options = {})
      manifest = deployment_model.manifest || '{}'
      manifest_text = deployment_model.manifest_text || '{}'
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(deployment_model.runtime_configs)
      consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(deployment_model.cloud_configs)
      load_manifest(YAML.safe_load(manifest, permitted_classes: [Symbol], aliases: true), manifest_text, consolidated_cloud_config, consolidated_runtime_config, options)
    end

    def self.load_from_hash(manifest_hash, manifest_text, cloud_configs, runtime_configs, options = {})
      consolidated_runtime_config = Bosh::Director::RuntimeConfig::RuntimeConfigsConsolidator.new(runtime_configs)
      consolidated_cloud_config = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(cloud_configs)
      load_manifest(manifest_hash, manifest_text, consolidated_cloud_config, consolidated_runtime_config, options)
    end

    def self.generate_empty_manifest()
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

    def diff(other_manifest, redact, teams)
      Changeset.new(to_hash_filter_addons(teams), other_manifest.to_hash_filter_addons(teams)).diff(redact).order
    end

    def to_hash
      merge_manifests(@manifest_hash, @cloud_config_hash, @runtime_config_hash)
    end

    def to_hash_filter_addons(teams)
      deployment = DeploymentConfig.new(@manifest_hash, teams.map(&:name))
      filtered_runtime_config = filter_addons(@runtime_config_hash, deployment)
      merge_manifests(@manifest_hash, @cloud_config_hash, filtered_runtime_config)
    end

    private

    def filter_addons(runtime_manifest, deployment)
      return deployment.manifest_hash if runtime_manifest == {} || !runtime_manifest.key?('releases')

      filtered_runtime_manifest = Bosh::Common::DeepCopy.copy(runtime_manifest)
      runtime_manifest_parser = Bosh::Director::RuntimeConfig::RuntimeManifestParser.new(Config.logger)
      parsed_runtime_config = runtime_manifest_parser.parse(runtime_manifest)

      applicable_releases = parsed_runtime_config.get_applicable_releases(deployment)
      filtered_runtime_manifest['releases'] = filter_releases_array(filtered_runtime_manifest['releases'], applicable_releases)

      applicable_addons = parsed_runtime_config.get_applicable_addons(deployment)
      filtered_runtime_manifest['addons'] = filter_addons_array(filtered_runtime_manifest['addons'], applicable_addons)

      filtered_runtime_manifest.compact
    end

    def filter_addons_array(addons, applicable_addons)
      return nil unless addons && applicable_addons

      filtered_addons = addons.select do |addon|
        applicable_addons.any? { |applicable_addon| applicable_addon.name == addon['name'] }
      end
      filtered_addons.empty? ? nil : filtered_addons
    end

    def filter_releases_array(releases, applicable_releases)
      return [] unless releases && applicable_releases

      releases.select do |release|
        applicable_releases.any? { |applicable_release| applicable_release.name == release['name'] }
      end
    end

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
            resolved_os = resolve_stemcell_os(stemcell)
            stemcell['os'] = resolved_os if resolved_os
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
        if (key == 'releases') || (key == 'variables') || (key == 'addons')
          if old && new
            old.to_set.merge(new.to_set).to_a
          else
            old.nil? ? new : old
          end
        elsif key == 'tags'
          if old && new
            new.merge(old)
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
        if stemcell['name']
          latest_stemcell = stemcell_manager.latest_by_name(stemcell['name'], resolvable_version[:prefix])
        elsif stemcell['os']
          latest_stemcell = stemcell_manager.latest_by_os(stemcell['os'], resolvable_version[:prefix])
        else
          raise 'Stemcell definition must contain either name or os'
        end
        return latest_stemcell[:version].to_s
      end

      stemcell['version'].to_s
    end

    def resolve_stemcell_os(stemcell)
      return stemcell['os'] if stemcell['os']

      stemcell_manager = Api::StemcellManager.new

      models = stemcell_manager.all_by_name_and_version(stemcell['name'], stemcell['version'])
      unless models.empty?
        models.first.operating_system
      end
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
