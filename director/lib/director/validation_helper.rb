module Bosh::Director
  module ValidationHelper
    def safe_property(hash, property, options = {})
      result = nil
      if hash && hash.has_key?(property)
        result = hash[property]
        if options[:class] && !result.kind_of?(options[:class])
          if options[:class] == String && result.kind_of?(Numeric)
            result = result.to_s
          else
            raise Bosh::Director::ValidationInvalidType.new(property, options[:class], hash.pretty_inspect)
          end
        end
      elsif !options[:optional]
        raise Bosh::Director::ValidationMissingField.new(property, hash.pretty_inspect)
      end
      result
    end
  end
end