# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DrainManager
    class << self
      DRAIN_WAIT = 3
      attr_accessor :lock, :draining
      def setup(thin_server)
        @lock = Mutex.new
        @draining = false
        @logger = Config.logger
        @thin_server = thin_server
        @start_time = Time.now

        ["TERM", "INT", "QUIT"].each do |signal|
          trap(signal) do
            shutdown
          end
        end

        trap("USR2") do
          begin_draining
        end
      end

      def shutdown
        @logger.info("Shutting down director")
        @thin_server.stop!
        EM.stop
      end

      def drain_and_shutdown
        raise "Cannot shutdown if director is not draining" unless @draining

        loop do
          @lock.synchronize do
            # Done after all pending tasks/jobs have finished
            if Models::Task.filter('timestamp >= ?', @start_time).filter({:state => ["processing", "queued"]}).count == 0
              shutdown
              return
            end
          end
          sleep DRAIN_WAIT
        end
      end

      def begin_draining
        @logger.info("Draining director")
        return if @draining

        # No new tasks created after this
        @draining = true

        Thread.new do
          drain_and_shutdown
        end
      end
    end
  end
end
