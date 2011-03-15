module Bosh::Director
  module ValidationHelper
    def safe_property(hash, property, options = {})
      result = nil
      if hash && hash.has_key?(property)
        result = hash[property]
        if options[:class]
          if options[:class] == :boolean
            unless result.kind_of?(TrueClass) || result.kind_of?(FalseClass)
              raise ValidationInvalidType.new(property, options[:class], hash.pretty_inspect)
            end
          elsif !result.kind_of?(options[:class])
            if options[:class] == String && result.kind_of?(Numeric)
              result = result.to_s
            else
              raise ValidationInvalidType.new(property, options[:class], hash.pretty_inspect)
            end
          end
        end
        raise ValidationViolatedMin.new(property, options[:min]) if options[:min] && result < options[:min]
        raise ValidationViolatedMax.new(property, options[:max]) if options[:max] && result > options[:max]
      elsif !options[:optional]
        raise ValidationMissingField.new(property, hash.pretty_inspect)
      end
      result
    end
  end
end