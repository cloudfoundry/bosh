module Bosh::Director
  module CpiConfig
    class Cpi
      extend ValidationHelper

      attr_reader :name, :type, :properties

      def initialize(name, type, exec_path, properties)
        @name = name
        @type = type
        @exec_path = exec_path
        @properties = properties
      end

      def self.parse(cpi_hash)
        name = safe_property(cpi_hash, 'name', :class => String)
        type = safe_property(cpi_hash, 'type', :class => String)
        exec_path = safe_property(cpi_hash, 'exec_path', :class => String, :optional => true)
        properties = safe_property(cpi_hash, 'properties', :class => Hash, :optional => true, :default => {})
        new(name, type, exec_path, properties)
      end

      def exec_path
        @exec_path || "/var/vcap/jobs/#{type}_cpi/bin/cpi"
      end
    end
  end
end
