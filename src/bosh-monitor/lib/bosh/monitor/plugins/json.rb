module Bosh::Monitor::Plugins
  class Json < Base
    attr_reader :processes

    def run
      unless EM.reactor_running?
        logger.error("JSON delivery agent can only be started when event loop is running")
        return false
      end

      @processes = Dir[bin_glob].map do |bin|
        EventMachine::DeferrableChildProcess.open(bin)
      end
    end

    def process(event)
      event_json = event.to_json
      @processes.each do |process|
        process.send_data "#{event_json}\n"
      end
    end

    private

    def bin_glob
      options.fetch('bin_glob', '/var/vcap/jobs/*/bin/bosh-monitor/*')
    end
  end
end
