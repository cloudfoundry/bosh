# Copyright (c) 2009-2012 VMware, Inc.

module VSphereCloud
  class Resources
    class Scorer

      # Run the scoring function and return the placement score for the required
      # resources.
      #
      # @param [Logging::Logger] logger logger to which to log.
      # @param [Integer] requested_memory required memory.
      # @param [Cluster] cluster requested cluster.
      # @param [Integer] requested_ephemeral_size disk size in mb.
      # @param [Array<Integer>] requested_persistent_sizes list of requested persistent sizes in mb.
      # @return [Integer] score.
      def self.score(logger, cluster, requested_memory, requested_ephemeral_size, requested_persistent_sizes)
        free_memory = cluster.free_memory
        ephemeral_pool = DiskPool.new(cluster.ephemeral_datastores.values.map(&:free_space))
        persistent_pool = DiskPool.new(cluster.persistent_datastores.values.map(&:free_space))

        successful_allocations = 0
        loop do
          free_memory -= requested_memory
          if free_memory < MEMORY_HEADROOM
            logger.debug("#{cluster.name} memory bound")
            break
          end

          unless ephemeral_pool.consume_disk(requested_ephemeral_size)
            logger.debug("#{cluster.name} ephemeral disk bound")
            break
          end

          unless requested_persistent_sizes.empty?
            placed = requested_persistent_sizes.select { |size| persistent_pool.consume_disk(size) }
            unless requested_persistent_sizes == placed
              logger.debug("#{cluster.name} persistent disk bound")
              break
            end
          end

          successful_allocations += 1
        end

        successful_allocations
      end

      private

      class DiskPool
        def initialize(sizes)
          @sizes = sizes
        end

        # Consumes disk space from a datastore pool.
        #
        # @param [Integer] requested_size requested disk size.
        # @return [true, false] boolean indicating that the disk space was consumed.
        def consume_disk(requested_size)
          unless @sizes.empty?
            @sizes.sort! { |a, b| b <=> a }
            if @sizes[0] >= requested_size + DISK_HEADROOM
              @sizes[0] -= requested_size
              return true
            end
          end

          false
        end
      end
    end
  end
end
