require 'open3'

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
      unless ::Async::Task.current?
        @logger.error('JSON Plugin can only be started when event loop is running')
        return false
      end

      Async do |task|
        loop do
          start_processes
          sleep(@check_interval)
        end
      end
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
        Async do
          sleep(@restart_wait)
          restart_process bin
        end
      end
      process.run

      process
    end
  end

  class DeferrableChildProcess
    def initialize(cmd)
      @cmd = cmd
      @data = []
      @errback = []
      @lock = Mutex.new
    end

    def run
      Async do |task|
        stdin, stdout, stderr, wait_thr = Open3.popen3(@cmd)

        @stdin = Async::IO::Stream.new(Async::IO::Generic.new(stdin))
        @stdout = Async::IO::Stream.new(Async::IO::Generic.new(stdout))
        @stderr = Async::IO::Stream.new(Async::IO::Generic.new(stderr))
        @wait_thr = wait_thr

        task.async do
          while (data = @stdout.read(1))
            receive_data(data)
          end
        end

        task.async do
          while (data = @stderr.read(1))
            receive_data(data)
          end
        end

        # Wait for the process to complete
        status = @wait_thr.value
        unless status.success?
          @errback.each do |errback|
            errback.call
          end
        end
      rescue => e
        @errback.each do |errback|
          errback.call
        end
      ensure
        @stdin.close if @stdin
        @stdout.close if @stdout
        @stderr.close if @stderr
      end
    end

    def self.open(cmd)
      new(cmd)
    end

    def errback(&block)
      @errback << block
    end

    def send_data(data)
      @stdin.write(data)
      @stdin.flush
    end

    def receive_data(data)
      @lock.synchronize do
        @data << data
      end
    end
  end
end
