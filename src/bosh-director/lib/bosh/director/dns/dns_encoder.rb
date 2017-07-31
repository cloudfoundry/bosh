module Bosh::Director
  class DnsEncoder
    def initialize(az_hash)
      @az_hash = az_hash
    end

    def encode_query(criteria)
      queries = []

      # these should be parsed in alphabetical order for the resulting encoded query.

      # present the AZs in index-sorted order
      azs = criteria[:azs]
      aznums = []
      unless azs.nil?
        azs.each do |az|
          aznums << id_for_az(az)
        end
      end

      queries << aznums.sort.map do |item|
        "a#{item}"
      end

      queries << 's0' # healthy by default; also prevents empty queries

      [
        "q-#{queries.join}",
        Canonicalizer.canonicalize(criteria[:instance_group]),
        Canonicalizer.canonicalize(criteria[:default_network]),
        Canonicalizer.canonicalize(criteria[:deployment_name]),
        criteria[:root_domain]
      ].join('.')
    end

    def id_for_az(az_name)
      if az_name.nil?
        return nil
      end

      index = @az_hash[az_name]
      raise RuntimeError.new("Unknown AZ: '#{az_name}'") if index.nil?
      index
    end
  end
end
