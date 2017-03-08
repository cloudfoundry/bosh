module Bosh::Director
  class SyncDnsScheduler
    def initialize(dns_version_converger, interval)
      @dns_version_converger = dns_version_converger
      @interval = interval
    end

    def start!
      @thread = Thread.new do
        loop do
          sleep(@interval)
          broadcast
        end
      end

      @thread[:name] = self.class.to_s
      @thread.join
    end

    def stop!
      @thread.exit
    end

    private

    def broadcast
      @dns_version_converger.update_instances_based_on_strategy
    end
  end
end
