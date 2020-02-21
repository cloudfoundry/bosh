module Bosh::Monitor
  class GraphiteConnection < Bosh::Monitor::TcpConnection
    def initialize(host, port, max_retries)
      super('connection.graphite', host, port, max_retries)
    end

    def send_metric(name, value, timestamp)
      if name && value && timestamp
        command = "#{name} #{value} #{timestamp}\n"
        @logger.debug("[Graphite] >> #{command.chomp}")
        send_data(command)
      else
        @logger.warn("Missing graphite metrics (name: '#{name}', value: '#{value}', timestamp: '#{timestamp}')")
      end
    end
  end
end
