module Bosh::Director
  class Manifest
    def self.load_from_text(manifest_text, cloud_config_hash)
      new(Psych.load(manifest_text), cloud_config_hash)
    end

    def initialize(manifest_hash, cloud_config_hash)
      @manifest_hash = manifest_hash
      @cloud_config_hash = cloud_config_hash
    end

    def resolve_aliases

    end

    def to_hash
      @manifest_hash.merge(@cloud_config_hash)
    end
  end
end
