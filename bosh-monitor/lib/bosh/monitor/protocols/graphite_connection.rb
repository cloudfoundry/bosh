module Bosh::Monitor
  class GraphiteConnection < Bosh::Monitor::TcpConnection
    def initialize(host, port)
      super("connection.graphite", host, port)
    end

    def send_metric(name, value, timestamp)
      if name && value && timestamp
        command = "#{name} #{value} #{timestamp}\n"
        @logger.debug("[Graphite] >> #{command.chomp}")
        send_data(command)
      end
    end
  end
end
