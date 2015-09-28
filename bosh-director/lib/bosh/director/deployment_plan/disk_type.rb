module Bosh::Director
  module DeploymentPlan
    class DiskType

      # @return [String] Disk types name
      attr_accessor :name

      # @return [Integer] Disk size (or nil)
      attr_accessor :disk_size

      # @return [Hash] cloud properties to use when creating VMs.
      attr_accessor :cloud_properties

      def self.parse(dp_spec)
        DiskTypesParser.new.parse(dp_spec)
      end

      def initialize(name)
        @name = name
        @disk_size = 0
        @cloud_properties = {}
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
          disk_types = DiskType.new(name)

          disk_size = safe_property(dp_spec, 'disk_size', class: Integer)

          if disk_size < 0
            raise DiskTypeInvalidDiskSize,
              "Disk types `#{name}' references an invalid persistent disk size `#{disk_size}'"
          end
          disk_types.disk_size = disk_size

          disk_types.cloud_properties = safe_property(dp_spec, 'cloud_properties', class: Hash, default: {})

          disk_types
        end
      end

    end
  end
end
