module VSphereCloud
  class Resources

    # Datastore resource.
    class Datastore
      PROPERTIES = %w(summary.freeSpace summary.capacity name)

      # @!attribute mob
      #   @return [Vim::Datastore] datastore vSphere MOB.
      attr_accessor :mob

      # @!attribute name
      #   @return [String] datastore name.
      attr_accessor :name

      # @!attribute total_space
      #   @return [Integer] datastore capacity.
      attr_accessor :total_space

      # @!attribute synced_free_space
      #   @return [Integer] datastore free space when fetched from vSphere.
      attr_accessor :synced_free_space

      # @!attribute allocated_after_sync
      #   @return [Integer] allocated space since vSphere fetch.
      attr_accessor :allocated_after_sync

      # Creates a Datastore resource from the prefetched vSphere properties.
      #
      # @param [Hash] properties prefetched vSphere properties to build the
      #   model.
      def initialize(properties)
        @mob = properties[:obj]
        @name = properties["name"]
        @total_space = properties["summary.capacity"].to_i / BYTES_IN_MB
        @synced_free_space = properties["summary.freeSpace"].to_i / BYTES_IN_MB
        @allocated_after_sync = 0
      end

      # @return [Integer] free disk space available for allocation
      def free_space
        @synced_free_space - @allocated_after_sync
      end

      # Marks the disk space against the cached utilization data.
      #
      # @param [Integer] space requested disk space.
      # @return [void]
      def allocate(space)
        @allocated_after_sync += space
      end

      # @return [String] debug datastore information.
      def inspect
        "<Datastore: #@mob / #@name>"
      end
    end
  end
end
