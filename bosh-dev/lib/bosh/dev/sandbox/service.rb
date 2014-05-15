require 'timeout'
require 'bosh/dev'
require 'securerandom'

module Bosh::Dev::Sandbox
  class Service
    attr_reader :description

    def initialize(cmd_array, cmd_options, logger)
      @cmd_array = cmd_array
      @cmd_options = cmd_options
      @logger = logger
      @pid = nil

      # Add unique identifier to avoid confusing log information
      @description = "#{@cmd_array.first} (#{SecureRandom.hex(4)})"

      @stdout = @cmd_options[:output]
      @stderr = "#{@stdout}.err" if @stdout
    end

    def start
      env = ENV.to_hash.merge(@cmd_options.fetch(:env, {}))

      if running?
        @logger.info("Already started #{@description} with PID #{@pid}")
      else
        unless system("which #{@cmd_array.first} > /dev/null")
          raise "Cannot find #{@description} in the $PATH"
        end

        @pid = Process.spawn(env, *@cmd_array, {
          out: @stdout || :close,
          err: @stderr || :close,
          in: :close,
        })
        @logger.info("Started #{@description} with PID #{@pid}")

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
      if running?
        kill_process(signal, @pid)

        # Block until process exits to avoid race conditions in the caller
        # (e.g. director process is killed but we don't wait and then we
        # try to delete db which is in use by director)
        wait_for_process_to_exit_or_be_killed
      end

      # Reset pid so that we do not think that service is still running
      # when pid is given to some other unrelated process
      @pid = nil
    end

    def stdout_contents
      @stdout ? File.read(@stdout) : ''
    end

    def stderr_contents
      @stderr ? File.read(@stderr) : ''
    end

    private

    def running?
      @pid && Process.kill(0, @pid)
    rescue Errno::ESRCH # No such process
      false
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@description} is running with PID=#{@pid} so this service is not running.")
      @logger.debug(`ps #{@pid}`)
      false
    end

    def wait_for_process_to_exit_or_be_killed(remaining_attempts = 30)
      while running?
        remaining_attempts -= 1
        if remaining_attempts == 5
          @logger.info("Killing #{@description} with PID=#{@pid}")
          kill_process('KILL', @pid)
        elsif remaining_attempts == 0
          raise "KILL signal ignored by #{@description} with PID=#{@pid}"
        end

        sleep(0.2)
      end
    end

    def kill_process(signal, pid)
      @logger.info("Terminating #{@description} with PID=#{pid}")
      Process.kill(signal, pid)
    rescue Errno::ESRCH # No such process
      @logger.info("Process #{@description} with PID=#{pid} not found")
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@description} is running with PID=#{pid} so this service is stopped.")
      @logger.debug(`ps #{pid}`)
    end
  end
end
