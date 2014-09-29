module Bosh::Director
  module DeploymentPlan
    class DiskPool

      # @return [String] Disk pool name
      attr_accessor :name

      # @return [Integer] Disk size (or nil)
      attr_accessor :disk_size

      # @return [Hash] cloud properties to use when creating VMs.
      attr_accessor :cloud_properties

      def self.parse(dp_spec)
        DiskPoolParser.new.parse(dp_spec)
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

      class DiskPoolParser
        include ValidationHelper

        def parse(dp_spec)
          name = safe_property(dp_spec, 'name', class: String)
          disk_pool = DiskPool.new(name)

          disk_size = safe_property(dp_spec, 'disk_size', class: Integer)

          if disk_size < 0
            raise DiskPoolInvalidDiskSize,
              "Disk pool `#{name}' references an invalid peristent disk size `#{disk_size}'"
          end
          disk_pool.disk_size = disk_size

          disk_pool.cloud_properties = safe_property(dp_spec, 'cloud_properties', class: Hash, default: {})

          disk_pool
        end
      end

    end
  end
end
