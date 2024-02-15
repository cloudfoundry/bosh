module Bosh::Monitor::Plugins
  class Json < Base
    def initialize(options = {})
      super(options)
      @process_manager = options.fetch('process_manager', Bosh::Monitor::Plugins::ProcessManager.new(glob: '/var/vcap/jobs/*/bin/bosh-monitor/*', logger: logger))
    end

    def run
      @process_manager.start
    end

    def process(event)
      @process_manager.send_event event
    end
  end

  class ProcessManager
    def initialize(options)
      @bin_glob = options.fetch(:glob)
      @logger = options.fetch(:logger)
      @check_interval = options.fetch(:check_interval, 60)
      @restart_wait = options.fetch(:restart_wait, 1)

      @lock = Mutex.new
      @processes = {}
    end

    def start
      unless EventMachine.reactor_running?
        @logger.error('JSON Plugin can only be started when event loop is running')
        return false
      end

      start_processes

      EventMachine.add_periodic_timer(@check_interval) { start_processes }
    end

    def send_event(event)
      @lock.synchronize do
        @processes.each do |_, process|
          process.send_data "#{event.to_json}\n"
        end

        @logger.debug("JSON Plugin: Sent to #{@processes.size} managed processes")
      end
    end

    private

    def start_processes
      @lock.synchronize do
        new_binaries = Dir[@bin_glob] - @processes.keys
        new_binaries.each do |bin|
          @processes[bin] = start_process(bin)
          @logger.info("JSON Plugin: Started process #{bin}")
        end
      end
    end

    def restart_process(bin)
      @lock.synchronize do
        @processes[bin] = start_process(bin)
        @logger.info("JSON Plugin: Restarted process #{bin}")
      end
    end

    def start_process(bin)
      process = Bosh::Monitor::Plugins::DeferrableChildProcess.open(bin)
      process.errback do
        EventMachine.add_timer(@restart_wait) { restart_process bin }
      end

      process
    end
  end

  # EventMachine's DeferrableChildProcess does not give an opportunity
  # to get the exit status. So we are implementing our own unbind logic to handle the exit status.
  # This way we can execute our process restart on the err callback (errback).
  # https://stackoverflow.com/a/12092647
  class DeferrableChildProcess < EventMachine::Connection
    include EventMachine::Deferrable

    def initialize
      super
      @data = []
    end

    def self.open(cmd)
      EventMachine.popen(cmd, DeferrableChildProcess)
    end

    def receive_data(data)
      @data << data
    end

    def unbind
      status = get_status
      if status.exitstatus != 0
        fail(status)
      else
        succeed(@data.join, status)
      end
    end
  end
end
