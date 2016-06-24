require 'set'

module Bosh::Director
  class Manifest
    def self.load_from_text(manifest_text, cloud_config, runtime_config)
      manifest_text ||= '{}'
      self.load_from_hash(YAML.load(manifest_text), cloud_config, runtime_config)
    end

    def self.load_from_hash(manifest_hash, cloud_config, runtime_config)
      cloud_config_hash =  cloud_config.nil? ? nil : cloud_config.manifest
      runtime_config_hash = runtime_config.nil? ? nil : runtime_config.manifest
      manifest_hash = manifest_hash.nil? ? {} : manifest_hash
      new(manifest_hash, cloud_config_hash, runtime_config_hash)
    end

    attr_reader :manifest_hash, :cloud_config_hash, :runtime_config_hash

    def initialize(manifest_hash, cloud_config_hash, runtime_config_hash)
      @manifest_hash = manifest_hash
      @cloud_config_hash = cloud_config_hash
      @runtime_config_hash = runtime_config_hash

      @config_map = []
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

    def fetch_config_values
      @config_map = Bosh::Director::Jobs::Helpers::DeepHashReplacement.replacement_map(@manifest_hash)
      config_keys = @config_map.map { |c| c["key"] }.uniq

      @config_values, invalid_keys = fetch_values_from_config_server(config_keys)
      if invalid_keys.length > 0
        raise "Failed to find keys in the config server: " + invalid_keys.join(", ")
      end

      @raw_manifest_hash = @manifest_hash
      @manifest_hash = parsed_manifest
    end

    def raw_manifest_hash
      @raw_manifest_hash || @manifest_hash
    end

    private

    def fetch_values_from_config_server(keys)
      invalid_keys = []
      config_values = {}

      keys.each do |k|
        config_server_url = URI.join(Bosh::Director::Config.config_server_url, 'v1/', 'config/', k)
        response = Net::HTTP.get_response(config_server_url)

        if response.kind_of? Net::HTTPSuccess
          config_values[k] = JSON.parse(response.body)['value']
        else
          invalid_keys << k
        end
      end

      [config_values, invalid_keys]
    end

    def parsed_manifest
      result = Bosh::Common::DeepCopy.copy(@manifest_hash)

      @config_map.each do |config_loc|
        config_path = config_loc['path']
        ret = config_path[0..config_path.length-2].inject(result) do |obj, el|
          obj[el]
        end

        ret[config_path.last] = @config_values[config_loc['key']]
      end

      result
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
