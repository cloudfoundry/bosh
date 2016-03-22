module Bosh::Director
  class Canonicalizer

    def self.canonicalize(string, opts = {})
      # a-z, 0-9, -, case insensitive, and must start with a letter
      string = string.downcase.gsub(/_/, "-")
      if opts[:allow_dots]
        string = string.gsub(/[^a-z0-9\-\.]/, "")
      else
        string = string.gsub(/[^a-z0-9\-]/, "")
      end

      validate_dns_name(string)
    end

    def self.validate_dns_name(string)
      if string =~ /^(\d|-)/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name '#{string}', must begin with a letter"
      end
      if string =~ /-$/
        raise DnsInvalidCanonicalName,
              "Invalid DNS canonical name '#{string}', can't end with a hyphen"
      end
      string
    end
  end
end
