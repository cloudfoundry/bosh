require 'timeout'
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
        until running?
          tries += 1
          raise RuntimeError, "Cannot run #{@cmd_array} with #{env.inspect}" if tries > 20
          sleep(0.1)
        end
      end
    end

    def stop(signal = 'TERM')
      return unless running?

      kill_process(signal, @pid)

      # Block until process exits to avoid race conditions in the caller
      # (e.g. director process is killed but we don't wait and then we
      # try to delete db which is in use by director)
      wait_for_process_to_exit_or_be_killed
    end

    private

    def running?
      @pid && Process.kill(0, @pid)
    rescue Errno::ESRCH # No such process
      false
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@cmd_array.first} is running with PID=#{@pid} so this service is not running.")
      @logger.debug(`ps #{@pid}`)
      false
    end

    def wait_for_process_to_exit_or_be_killed(remaining_attempts = 30)
      while running?
        remaining_attempts -= 1
        if remaining_attempts == 5
          @logger.info("Killing #{@cmd_array.first} with PID=#{@pid}")

          kill_process('KILL', @pid)
        elsif remaining_attempts == 0
          raise "KILL signal ignored by #{@cmd_array.first} with PID=#{@pid}"
        end

        sleep(0.2)
      end
    end

    def kill_process(signal, pid)
      @logger.info("Terminating #{@cmd_array.first} with PID=#{pid}")
      Process.kill(signal, pid)
    rescue Errno::ESRCH # No such process
      @logger.info("Process #{@cmd_array.first} with PID=#{pid} not found")
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@cmd_array.first} is running with PID=#{pid} so this service is stopped.")
      @logger.debug(`ps #{pid}`)
    end
  end
end
