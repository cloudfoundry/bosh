module Bosh::HealthMonitor
  class TsdbConnection < EventMachine::Connection

    RECONNECT_INTERVAL = 2 # seconds
    MAX_RETRIES = 10

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

      if @connected || @reconnecting
        if @retries <= MAX_RETRIES
          EM.add_timer(RECONNECT_INTERVAL) do
            @retries += 1
            @logger.info("Trying to reconnect to TSDB server at #{@host}:#{@port} (#{@retries})...")
            reconnect(@host, @port)
          end
          @reconnecting = true
        else
          @reconnecting = false
        end
        @connected = false
      else
        error_msg = "Couldn't connect to TSDB server at #{@host}:#{@port}"
        @logger.fatal(error_msg)
        raise ConnectionError, error_msg
      end
    end

    def receive_data(data)
      @logger.info("[TSDB] << #{data.chomp}")
    end

  end
end
