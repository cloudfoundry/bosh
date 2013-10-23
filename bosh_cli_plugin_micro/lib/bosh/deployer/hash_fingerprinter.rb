require 'digest/sha1'
require 'yajl'

module Bosh::Deployer
  class HashFingerprinter
    def sha1(hash)
      encoded = JSON.dump(sorted_hash(hash))
      Digest::SHA1.hexdigest(encoded)
    end

    private

    def sorted_hash(hash)
      mapped_hash = hash.map do |k, v|
        sorted_value = v.is_a?(Hash) ? sorted_hash(v) : v
        [k, sorted_value]
      end

      mapped_hash.sort_by { |(k, _)| k }
    end
  end
end
