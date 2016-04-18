require 'set'

module Bosh::Director
  class Manifest
    def self.load_from_text(manifest_text, cloud_config, runtime_config)
      cloud_config_hash =  cloud_config.nil? ? nil : cloud_config.manifest
      runtime_config_hash = runtime_config.nil? ? nil : runtime_config.manifest
      manifest_hash = manifest_text.nil? ? {} : Psych.load(manifest_text)
      new(manifest_hash, cloud_config_hash, runtime_config_hash)
    end

    attr_reader :manifest_hash, :cloud_config_hash, :runtime_config_hash

    def initialize(manifest_hash, cloud_config_hash, runtime_config_hash)
      @manifest_hash = manifest_hash
      @cloud_config_hash = cloud_config_hash
      @runtime_config_hash = runtime_config_hash
    end

    def resolve_aliases
      hashed = to_hash
      hashed['resource_pools'].to_a.each do |rp|
        rp['stemcell']['version'] = resolve_stemcell_version(rp['stemcell'])
      end

      hashed['stemcells'].to_a.each do |stemcell|
        stemcell['version'] = resolve_stemcell_version(stemcell)
      end

      hashed['releases'].to_a.each do |release|
        release['version'] = resolve_release_version(release)
      end
    end

    def diff(other_manifest, redact)
      Changeset.new(to_hash, other_manifest.to_hash).diff(redact).order
    end

    def to_hash
      hash = @manifest_hash.merge(@cloud_config_hash || {})
      hash.merge(@runtime_config_hash || {}) do |key, old, new|
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

    private

    def resolve_stemcell_version(stemcell)
      stemcell_manager = Api::StemcellManager.new

      unless stemcell.is_a?(Hash)
        raise 'Invalid stemcell spec in the deployment manifest'
      end

      if stemcell['version'] == 'latest'
        if stemcell['os']
          latest_stemcell = stemcell_manager.latest_by_os(stemcell['os'])
        elsif stemcell['name']
          latest_stemcell = stemcell_manager.latest_by_name(stemcell['name'])
        else
          raise 'Stemcell definition must contain either name or os'
        end
        return latest_stemcell[:version].to_s
      end

      stemcell['version'].to_s
    end

    def resolve_release_version(release_def)
      release_manager = Api::ReleaseManager.new
      if release_def['version'] == 'latest'
        release = release_manager.find_by_name(release_def['name'])
        return release_manager.sorted_release_versions(release).last['version']
      end

      release_def['version'].to_s
    end
  end
end
