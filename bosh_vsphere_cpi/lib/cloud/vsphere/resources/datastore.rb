require 'cloud/vsphere/resources'

module VSphereCloud
  class Resources
    class Datastore
      include VimSdk
      PROPERTIES = %w(summary.freeSpace summary.capacity name)

      def self.build_from_client(client, datastore_properties)
        ds_properties_map = client.cloud_searcher.get_properties(datastore_properties, Vim::Datastore, Datastore::PROPERTIES)
        ds_properties_map.values.map do |ds_properties|
          Datastore.new(
            ds_properties['name'],
            ds_properties[:obj],
            ds_properties['summary.capacity'].to_i / BYTES_IN_MB,
            ds_properties['summary.freeSpace'].to_i / BYTES_IN_MB,
          )
        end
      end

      # @!attribute name
      #   @return [String] datastore name.
      attr_accessor :name

      # @!attribute mob
      #   @return [Vim::Datastore] datastore vSphere MOB.
      attr_accessor :mob

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
      def initialize(name, mob, total_space, synced_free_space)
        @name = name
        @mob = mob
        @total_space = total_space
        @synced_free_space = synced_free_space
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

      def debug_info
        "#{name} (#{free_space}MB free of #{total_space}MB capacity)"
      end
    end
  end
end
