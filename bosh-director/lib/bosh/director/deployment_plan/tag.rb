module Bosh::Director
  module DeploymentPlan
    class Tag
      extend ValidationHelper

      attr_reader :key
      attr_reader :value

      def self.parse(spec)
        key = get_safe_key(spec)
        value = get_safe_value(key, spec)

        new(key, value)
      end


      def initialize(key, value)
        @key = key
        @value = value
      end

      private

      def self.get_safe_key(spec)
        key = spec.keys.first

        if !key.is_a? String
          raise ValidationInvalidType, "Tag 'key' must be a string"
        end

        key
      end

      def self.get_safe_value(key, spec)
        value = spec[key]

        if value.nil?
          raise ValidationMissingField, "Required property 'value' was not specified in object (#{spec})"
        end

        if !value.is_a? String
          raise ValidationInvalidType, "Tag 'value' must be a string"
        end
        value
      end
    end
  end
end
