module Bosh::Monitor
  class GraphiteConnection < Bosh::Monitor::TcpConnection
    def initialize(host, port, max_retries)
      super('connection.graphite', host, port, max_retries)
    end

    def send_metric(name, value, timestamp)
      if [name, value, timestamp].all? { |part| part && /\A[^\s[:cntrl:]]+\z/.match?(part.to_s) }
        command = "#{name} #{value} #{timestamp}\n"
        @logger.debug("[Graphite] >> #{command.chomp}")
        send_data(command)
      else
        @logger.warn("Invalid graphite metric")
      end
    end
  end
end
