module Bosh::Director
  module ValidationHelper
    def safe_property(hash, property, options = {})
      result = nil

      if hash && !hash.kind_of?(Hash)
        raise Bosh::Director::ValidationInvalidType,
              "Object (#{hash.inspect}) did not match the required type `Hash'"

      elsif hash && hash.has_key?(property)
        result = hash[property]

        if options[:class]
          if options[:class] == :boolean
            unless result.kind_of?(TrueClass) || result.kind_of?(FalseClass)
              invalid_type(property, options[:class], result)
            end

          elsif !result.kind_of?(options[:class])
            if options[:class] == String && result.kind_of?(Numeric)
              result = result.to_s
            else
              invalid_type(property, options[:class], result)
            end
          end
        end

        if options[:min] && result < options[:min]
          raise ValidationViolatedMin,
                "`#{property}' value (#{result.inspect}) should be greater than #{options[:min].inspect}"
        end

        if options[:max] && result > options[:max]
          raise ValidationViolatedMax,
                "`#{property}' value (#{result.inspect}) should be less than #{options[:max].inspect}"
        end

      elsif options[:default]
        result = options[:default]

      elsif !options[:optional]
        raise ValidationMissingField,
              "Required property `#{property}' was not specified in object (#{hash.inspect})"
      end

      result
    end

    def invalid_type(property, klass, value)
      raise ValidationInvalidType,
            "Property `#{property}' (value #{value.inspect}) did not match the required type `#{klass}'"
    end
  end
end
