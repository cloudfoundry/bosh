module Bosh::Director::CloudProviders::VSphere
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
          @client.service.httpNfcLeaseProgress(HttpNfcLeaseProgressRequestType.new(@lease, @progress))
        end
        sleep(1)
      end
    end

    def abort
      @lock.synchronize do
        @state = :abort
        @client.service.httpNfcLeaseAbort(HttpNfcLeaseAbortRequestType.new(@lease))
      end
    end

    def finish
      @lock.synchronize do
        @state = :finish
        @client.service.httpNfcLeaseProgress(HttpNfcLeaseProgressRequestType.new(@lease, 100))
        @client.service.httpNfcLeaseComplete(HttpNfcLeaseCompleteRequestType.new(@lease))
      end
    end

  end
end
