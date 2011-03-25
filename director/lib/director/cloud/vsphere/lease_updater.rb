module VSphereCloud
  class LeaseUpdater
    attr_accessor :progress

    def initialize(client, lease)
      @progress = 0
      @client = client
      @lease = lease
      @state = :running
      @lock = Mutex.new
      @thread = Thread.new { run }
    end

    def run
      loop do
        @lock.synchronize do
          break if @state != :running
          @lease.progress(@progress)
        end
        sleep(1)
      end
    end

    def abort
      @lock.synchronize do
        @state = :abort
        @lease.abort
      end
    end

    def finish
      @lock.synchronize do
        @state = :finish
        @lease.progress(100)
        @lease.complete
      end
    end

  end
end
