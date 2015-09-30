require 'bosh/dev/bat'
require 'bosh/dev/writable_manifest'

module Bosh::Dev::Bat
  class DeploymentManifest
    include Bosh::Dev::WritableManifest

    attr_reader :filename
    attr_accessor :director_uuid, :net_type, :stemcell

    def self.load_from_file(bat_deployment_spec_path)
      config_contents = File.read(bat_deployment_spec_path)
      load(config_contents)
    end

    def self.load(bat_deployment_spec_yaml)
      manifest_hash = YAML.load(bat_deployment_spec_yaml)
      new(manifest_hash)
    rescue SyntaxError => e
      puts "Failed to load BAT deployment config yaml:\n#{bat_deployment_spec_yaml}"
      raise e
    end

    def initialize(manifest_hash)
      @manifest_hash = manifest_hash
      @filename = 'bat.yml'
      @net_type = 'dynamic'
      load_defaults
    end

    def load_defaults
      @manifest_hash['properties']['pool_size'] ||= 1
      @manifest_hash['properties']['instances'] ||= 1
    end

    def stemcell=(stemcell_archive)
      @stemcell = stemcell_archive
      @manifest_hash['properties']['stemcell'] = {
        'name' => stemcell_archive.name,
        'version' => stemcell_archive.version
      }
    end

    def to_h
      # uuid is lazy-loaded after targeting the director
      @manifest_hash['properties']['uuid'] = director_uuid.value if director_uuid

      @manifest_hash
    end

    def ==(other)
      to_h == other.to_h
    end
  end
end
