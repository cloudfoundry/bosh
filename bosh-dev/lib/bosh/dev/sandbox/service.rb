require 'bosh/dev'

module Bosh::Dev::Sandbox
  class Service
    def initialize(cmd_array, cmd_options, logger)
      @cmd_array = cmd_array
      @cmd_options = cmd_options
      @logger = logger
      @pid = nil
    end

    def start
      env = ENV.to_hash.merge(@cmd_options.fetch(:env, {}))
      output = @cmd_options.fetch(:output, :close)
      err_output = output == :close ? output : "#{output}.err"

      if running?
        @logger.info("Already started #{@cmd_array.first} with PID #{@pid}")
      else
        unless system("which #{@cmd_array.first} > /dev/null")
          raise "Cannot find #{@cmd_array.first} in the $PATH"
        end

        @pid = Process.spawn(env, *@cmd_array, out: output, err: err_output, in: :close)
        @logger.info("Started #{@cmd_array.first} with PID #{@pid}")

        Process.detach(@pid)
        tries = 0

        while !running?
          tries += 1
          raise RuntimeError, "Cannot run #{@cmd_array} with #{env.inspect}" if tries > 20
          sleep(0.1)
        end
      end
    end

    def stop(signal="TERM")
      return unless running?
      @logger.info("Killing #{@cmd_array.first} with PID=#{@pid}")
      Process.kill(signal, @pid)
    rescue Errno::ESRCH
      @logger.info("Process #{@cmd_array.first} with PID=#{@pid} not found")
    end

    private

    def running?
      @pid && Process.kill(0, @pid)
    rescue Errno::ESRCH
      false
    end
  end
end
