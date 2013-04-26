module Bosh::Director
  module Jobs
    class CreateSnapshot < BaseJob

      @queue = :normal

      def initialize(instance, options)
        @instance = instance
        @options = options
      end

      def perform
        Bosh::Director::Api::SnapshotManager.take_snapshot(@instance, @options)
      end
    end
  end
end
