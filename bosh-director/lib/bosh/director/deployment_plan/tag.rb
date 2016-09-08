module Bosh::Director
  module DeploymentPlan
    class Tag
      extend ValidationHelper

      attr_reader :key
      attr_reader :value

      def self.parse(spec)
        key = safe_property(spec, 'key', :class => String)
        value = safe_property(spec, 'value', :class => String)

        if key.nil? && value.nil?
          raise ValidationMissingField, "Required property 'key' or 'value' was not specified in object (#{spec})"
        end

        new(key, value)
      end

      def initialize(key, value)
        @key = key
        @value = value
      end
    end
  end
end
