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
        interpolated_cpi_hash = (Bosh::Director::ConfigServer::VariablesInterpolator.new)
                                    .interpolate_cpi_config(cpi_hash)

        name = safe_property(interpolated_cpi_hash, 'name', :class => String)
        type = safe_property(interpolated_cpi_hash, 'type', :class => String)
        exec_path = safe_property(interpolated_cpi_hash, 'exec_path', :class => String, :optional => true)

        properties = safe_property(interpolated_cpi_hash, 'properties', :class => Hash, :optional => true, :default => {})

        new(name, type, exec_path, properties)
      end

      def exec_path
        @exec_path || "/var/vcap/jobs/#{type}_cpi/bin/cpi"
      end
    end
  end
end
