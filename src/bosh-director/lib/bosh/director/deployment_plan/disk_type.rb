module Bosh::Director
  module DeploymentPlan
    class DiskType

      # @return [String] Disk types name
      attr_reader :name

      # @return [Integer] Disk size (or nil)
      attr_reader :disk_size

      # @return [Hash] cloud properties to use when creating VMs.
      attr_reader :cloud_properties

      def self.parse(dp_spec)
        DiskTypesParser.new.parse(dp_spec)
      end

      def initialize(name, disk_size, cloud_properties)
        @name = name
        @disk_size = disk_size
        @cloud_properties = cloud_properties
      end

      def spec
        {
          'name' => name,
          'disk_size' => disk_size,
          'cloud_properties' => cloud_properties,
        }
      end

      private

      class DiskTypesParser
        include ValidationHelper

        def parse(dp_spec)
          name = safe_property(dp_spec, 'name', class: String)
          disk_size = safe_property(dp_spec, 'disk_size', class: Integer)
          if disk_size < 0
            raise DiskTypeInvalidDiskSize,
              "Disk types '#{name}' references an invalid persistent disk size '#{disk_size}'"
          end

          cloud_properties = safe_property(dp_spec, 'cloud_properties', class: Hash, default: {})

          DiskType.new(name, disk_size, cloud_properties)
        end
      end
    end
  end
end
