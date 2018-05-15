module Bosh::Cpi
  class Redactor

    REDACTED = '<redacted>'

    def self.clone_and_redact(hash, *paths)
      begin
        hash = JSON.parse(hash.to_json)
      rescue
        return nil
      end

      redact!(hash, *paths)
    end

    def self.redact!(hash, *json_paths)
      json_paths.each do |json_path|
        properties = json_path.split('.')
        property_to_redact = properties.pop

        target_hash = properties.reduce(hash, &fetch_property)
        target_hash[property_to_redact] = REDACTED if target_hash.has_key? property_to_redact
      end

      hash
    end

    def self.fetch_property
      -> (hash, property) { hash.fetch(property, {})}
    end
  end
end