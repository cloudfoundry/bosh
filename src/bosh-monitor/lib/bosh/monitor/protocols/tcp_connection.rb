module Bosh::Monitor
  class TcpConnection < EventMachine::Connection
    BACKOFF_CEILING = 9
    MAX_RETRIES = 35

    attr_reader :retries, :logger_name

    def initialize(logger_name, host, port)
      @logger_name = logger_name
      @host = host
      @port = port
      @logger = Bhm.logger
      reset_retries
    end

    def reset_retries
      @retries = 0
    end

    def increment_retries
      @retries += 1
    end

    def connection_completed
      reset_retries
      @reconnecting = false
      @connected = true
      @logger.info("#{@logger_name}-connected")
    end

    def unbind
      @logger.warn("#{@logger_name}-connection-lost") if @connected
      @connected = false

      retry_in = 2**[retries, BACKOFF_CEILING].min - 1
      increment_retries

      raise "#{logger_name}-failed-to-reconnect after #{MAX_RETRIES} retries" if retries > MAX_RETRIES

      @logger.info("#{logger_name}-failed-to-reconnect, will try again in #{retry_in} seconds...") if retries > 1

      EM.add_timer(retry_in) { retry_reconnect }
    end

    def retry_reconnect
      @logger.info("#{@logger_name}-reconnecting (#{retries})...")
      reconnect(@host, @port)
    end

    def receive_data(data)
      @logger.info("#{logger_name} << #{data.chomp}")
    end
  end
end
