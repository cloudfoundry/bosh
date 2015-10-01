require 'timeout'
require 'bosh/dev'
require 'securerandom'
require 'thread'

module Bosh::Dev::Sandbox
  class Service
    attr_reader :description
    attr_accessor :pid

    def initialize(cmd_array, cmd_options, logger)
      @cmd_array = cmd_array
      @cmd_options = cmd_options
      @logger = logger
      @pid = nil

      # Add unique identifier to avoid confusing log information
      @log_id = SecureRandom.hex(4)
      @description = "#{@cmd_array.first} (#{@log_id})"
    end

    def start
      env = ENV.to_hash.merge(@cmd_options.fetch(:env, {}))
      @logger.info("Starting #{@description} with command: #{@cmd_array.inspect}, and options: #{@cmd_options.inspect}")

      if running?(@pid)
        @logger.info("Already started #{@description} with PID #{@pid}")
      else
        Dir.chdir(@cmd_options.fetch(:working_dir, Dir.pwd)) do
          unless system("which #{@cmd_array.first} > /dev/null")
            raise "Cannot find #{@description} in the $PATH"
          end

          @pid = Process.spawn(env, *@cmd_array, {
              out: stdout || :close,
              err: stderr || :close,
              in: :close,
            })

          @logger.info("Started process for #{@description} with PID #{@pid}, log-id: #{@log_id}")
        end
      end
    end

    def stop(signal = 'TERM')
      pid_to_stop = @pid
      @pid = nil
      @logger.info("Stopping #{@description} with PID=#{pid_to_stop}")

      if running?(pid_to_stop)
        kill_process(signal, pid_to_stop)

        # Block until process exits to avoid race conditions in the caller
        # (e.g. director process is killed but we don't wait and then we
        # try to delete db which is in use by director)
        wait_for_process_to_exit_or_be_killed(pid_to_stop)
      else
        @logger.debug("Process #{@description} with PID=#{pid_to_stop} is not running.")
      end
    end

    def stdout_contents
      stdout ? File.read(stdout) : ''
    end

    def stderr_contents
      stderr ? File.read(stderr) : ''
    end

    private

    def running?(pid)
      pid && Process.kill(0, pid)
    rescue Errno::ESRCH # No such process
      false
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@description} is running with PID=#{pid} so this service is not running.")
      @logger.debug(`ps #{pid}`)
      false
    end

    def wait_for_process_to_exit_or_be_killed(pid, kill_on_timeout = true)
      Timeout::timeout(20) do
        Process.wait(pid)
      end
    rescue Timeout::Error => e
      if kill_on_timeout
        kill_process('KILL', pid)
        wait_for_process_to_exit_or_be_killed(pid, false)
      else
        raise "KILL signal ignored by #{@description} with PID=#{pid}"
      end
    end

    def kill_process(signal, pid)
      @logger.info("Killing #{@description} (pid: #{pid}) with SIG#{signal}.")
      Process.kill(signal, pid)
    rescue Errno::ESRCH # No such process
      @logger.info("Process #{@description} with PID=#{pid} not found")
    rescue Errno::EPERM # Owned by some other user/process
      @logger.info("Process other than #{@description} is running with PID=#{pid} so this service is stopped.")
      @logger.debug(`ps #{pid}`)
    end

    def stdout
      if @cmd_options[:output]
        "#{@cmd_options[:output]}-#{@log_id}"
      else
        @cmd_options[:stdout]
      end
    end

    def stderr
      if @cmd_options[:output]
        "#{@cmd_options[:output]}-#{@log_id}.err"
      else
        @cmd_options[:stderr]
      end
    end
  end
end
