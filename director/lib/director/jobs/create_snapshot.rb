module Bosh::Director
  module Jobs
    class CreateSnapshot < BaseJob

      @queue = :normal

      def initialize(instance, options)
        @instance = instance
        @options = options
      end

      def perform
        SnapshotManager.snapshot(@instance, @options)
      end
    end
  end
end
