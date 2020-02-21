module Bosh::Monitor
  class TsdbConnection < Bosh::Monitor::TcpConnection
    def initialize(host, port, max_retries)
      super('connection.tsdb', host, port, max_retries)
    end

    def send_metric(name, timestamp, value, tags = {})
      formatted_tags = tags.map { |tag| tag.join('=') }.sort.join(' ')
      command = "put #{name} #{timestamp} #{value} #{formatted_tags}\n"
      @logger.debug("[TSDB] >> #{command.chomp}")
      send_data(command)
    end
  end
end
