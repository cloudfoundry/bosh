# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module ValidationHelper

    def safe_property(hash, property, options = {})
      result = nil

      if hash && hash.has_key?(property)
        result = hash[property]

        if options[:class]

          if options[:class] == :boolean
            unless result.kind_of?(TrueClass) || result.kind_of?(FalseClass)
              invalid_type(property, options[:class])
            end

          elsif !result.kind_of?(options[:class])
            if options[:class] == String && result.kind_of?(Numeric)
              result = result.to_s
            else
              invalid_type(property, options[:class])
            end
          end

        end

        if options[:min] && result < options[:min]
          raise ValidationViolatedMin,
                "`#{property}' value should be greater than #{options[:min]}"
        end

        if options[:max] && result > options[:max]
          raise ValidationViolatedMax,
                "`#{property}' value should be less than #{options[:max]}"
        end

      elsif options[:default]
        result = options[:default]

      elsif !options[:optional]
        raise ValidationMissingField,
              "Required property `#{property}' was not specified"
      end
      result
    end

    private

    def invalid_type(property, klass)
      raise ValidationInvalidType,
            "Property `#{property}' did not match the required type `#{klass}'"
    end

  end
end
