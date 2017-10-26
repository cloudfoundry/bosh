module Bosh::Director
  class Canonicalizer

    def self.canonicalize(string, opts = {})
      string = string.downcase.gsub(/_/, "-")
      if opts[:allow_dots]
        string = string.gsub(/[^a-z0-9\-\.]/, "")
      else
        string = string.gsub(/[^a-z0-9\-]/, "")
      end

      validate_dns_name(string)
    end

    def self.validate_dns_name(string)
      if string =~ /^-/
        raise DnsInvalidCanonicalName,
          "Invalid DNS canonical name '#{string}', cannot start with a hyphen"
      end
      if string =~ /-$/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name '#{string}', cannot end with a hyphen"
      end

      string
    end
  end
end
