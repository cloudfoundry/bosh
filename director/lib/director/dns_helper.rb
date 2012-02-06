module Bosh::Director
  module DnsHelper
    def canonical(string)
      # a-z, 0-9, -, case insensitive, and must start with a letter
      string = string.downcase.gsub(/_/, "-").gsub(/[^a-z0-9-]/, "")
      raise ValidationViolatedFormat.new(string, "must begin with a letter") if string =~ /^(\d|-)/
      raise ValidationViolatedFormat.new(string, "can't end with a hyphen") if string =~ /-$/
      string
    end
  end
end