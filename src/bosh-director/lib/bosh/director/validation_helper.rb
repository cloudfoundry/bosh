module Bosh::Director
  module ValidationHelper
    def safe_property(hash, property, options = {})

      if options.has_key?(:default) && !options[:default].nil?
        validate_property(property, options, options[:default], DefaultPropertyValidationMessage.new)
      end

      if !hash.nil? && !hash.kind_of?(Hash)
        raise Bosh::Director::ValidationInvalidType, "Object (#{hash.inspect}) did not match the required type 'Hash'"
      elsif !hash.nil? && hash.has_key?(property)
        return validate_property(property, options, hash[property], PropertyValidationMessage.new)
      elsif options.has_key?(:default)
        return options[:default]
      elsif !options[:optional]
        raise ValidationMissingField, "Required property '#{property}' was not specified in object (#{hash.inspect})"
      end
    end

    private

    def validate_property(property, options, result, validation_message)
      if options.has_key?(:class)
        required_type = options[:class]
        if required_type == :boolean
          unless result.kind_of?(TrueClass) || result.kind_of?(FalseClass)
            raise ValidationInvalidType, validation_message.invalid_type(property, required_type, result)
          end
        elsif !result.kind_of?(required_type)
          if required_type == String && result.kind_of?(Numeric)
            result = result.to_s
          else
            raise ValidationInvalidType, validation_message.invalid_type(property, required_type, result)
          end
        end
      end

      if options[:min] && result < options[:min]
        raise ValidationViolatedMin, validation_message.invalid_min(options, property, result)
      end

      if options[:max] && result > options[:max]
        raise ValidationViolatedMax, validation_message.invalid_max(options, property, result)
      end

      if options[:min_length] && result.length < options[:min_length]
        raise ValidationViolatedMin, validation_message.invalid_min_length(options, property, result)
      end

      if options[:max_length] && result.length > options[:max_length]
        raise ValidationViolatedMax, validation_message.invalid_max_length(options, property, result)
      end

      result
    end
  end

  class PropertyValidationMessage
    def invalid_type(property, klass, value)
      "Property '#{property}' value (#{value.inspect}) did not match the required type '#{klass}'"
    end

    def invalid_max(options, property, result)
      "'#{property}' value (#{result.inspect}) should be less than #{options[:max].inspect}"
    end

    def invalid_min(options, property, result)
      "'#{property}' value (#{result.inspect}) should be greater than #{options[:min].inspect}"
    end

    def invalid_max_length(options, property, result)
      "'#{property}' length (#{result.length.inspect}) should be less than #{options[:max_length].inspect}"
    end

    def invalid_min_length(options, property, result)
      "'#{property}' length (#{result.length.inspect}) should be greater than #{options[:min_length].inspect}"
    end
  end

  class DefaultPropertyValidationMessage
    def invalid_type(property, klass, value)
      "Default value for property '#{property}' value (#{value.inspect}) did not match the required type '#{klass}'"
    end

    def invalid_max(options, property, result)
      "Default value for property '#{property}' value (#{result.inspect}) should be less than #{options[:max].inspect}"
    end

    def invalid_min(options, property, result)
      "Default value for property '#{property}' value (#{result.inspect}) should be greater than #{options[:min].inspect}"
    end
  end
end
