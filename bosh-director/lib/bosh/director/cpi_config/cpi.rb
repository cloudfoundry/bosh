module Bosh::Director
  module CpiConfig
    class Cpi
      extend ValidationHelper

      attr_reader :name, :type, :properties

      def initialize(name, type, properties)
        @name = name
        @type = type
        @properties = properties
        validate
      end

      def self.parse(cpi_hash)
        name = safe_property(cpi_hash, 'name', :class => String)
        version = safe_property(cpi_hash, 'type', :class => String)
        properties = safe_property(cpi_hash, 'properties', :class => Hash, :optional => true, :default => {})
        new(name, version, properties)
      end

      private

      def validate
        # add further validation in future here (raise exceptions)
        true
      end
    end
  end
end
