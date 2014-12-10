module Bosh::Monitor
  class GraphiteConnection < EventMachine::Connection

    BACKOFF_CEILING = 9
    MAX_RETRIES = 35

    attr_reader :retries

    def initialize(host, port)
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

    def send_metric(name, value, timestamp)
      if name && value && timestamp
        command = "#{name} #{value} #{timestamp}\n"
        @logger.debug("[Graphite] >> #{command.chomp}")
        send_data(command)
      end
    end

    def connection_completed
      reset_retries
      @reconnecting = false
      @connected = true
      @logger.info("Connected to Graphite server at #{@host}:#{@port}")
    end

    def unbind
      if @connected
        @logger.warn("Lost connection to Graphite server at #{@host}:#{@port}")
      end
      @connected = false

      retry_in = 2**[retries, BACKOFF_CEILING].min - 1
      increment_retries

      if retries > MAX_RETRIES
        raise "Failed to reconnect to Graphite after #{MAX_RETRIES} retries"
      end

      if retries > 1
        @logger.info("Failed to reconnect to Graphite, will try again in #{retry_in} seconds...")
      end

      EM.add_timer(retry_in) { tsdb_reconnect }
    end

    def tsdb_reconnect
      @logger.info("Trying to reconnect to Graphite server at #{@host}:#{@port} (#{retries})...")
      reconnect(@host, @port)
    end

    def receive_data(_)
    end

  end
end
