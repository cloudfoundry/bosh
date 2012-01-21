module Bosh::HealthMonitor
  class TsdbConnection < EventMachine::Connection

    BACKOFF_CEILING = 9

    def initialize(host, port)
      @host = host
      @port = port
      @logger = Bhm.logger
    end

    def send_metric(name, timestamp, value, tags = {})
      formatted_tags = tags.map { |tag| tag.join("=") }.sort.join(" ")
      command = "put #{name} #{timestamp} #{value} #{formatted_tags}\n"
      @logger.debug("[TSDB] >> #{command.chomp}")
      send_data(command)
    end

    def connection_completed
      @retries = 0
      @reconnecting = false
      @connected = true
      @logger.info("Connected to TSDB server at #{@host}:#{@port}")
    end

    def unbind
      if @connected
        @logger.warn("Lost connection to TSDB server at #{@host}:#{@port}")
      end
      @connected = false

      retry_in = 2**[@retries, BACKOFF_CEILING].min - 1
      @retries += 1

      if @retries > 1
        @logger.info("Failed to reconnect to TSDB, will try again in #{retry_in} seconds...")
      end

      EM.add_timer(retry_in) { tsdb_reconnect }
    end

    def tsdb_reconnect
      @logger.info("Trying to reconnect to TSDB server at #{@host}:#{@port} (#{@retries})...")
      reconnect(@host, @port)
    end

    def receive_data(data)
      @logger.info("[TSDB] << #{data.chomp}")
    end

  end
end
