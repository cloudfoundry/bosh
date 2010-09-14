module Bosh::Director
  module ValidationHelper
    def safe_property(hash, property, options = {})
      result = nil
      if hash && hash.has_key?(property)
        result = hash[property]
        if options[:class] && !result.kind_of?(options[:class])
          raise "field: #{property} did not match the required type #{options[:class]} in #{hash.pretty_inspect}."
        end
      elsif !options[:optional]
        raise "required field: #{property} was not specified in #{hash.pretty_inspect}."
      end
      result
    end
  end
end