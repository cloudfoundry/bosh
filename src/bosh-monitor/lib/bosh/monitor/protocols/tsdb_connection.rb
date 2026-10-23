module Bosh::Monitor
  class TsdbConnection < Bosh::Monitor::TcpConnection
    def initialize(host, port, max_retries)
      super('connection.tsdb', host, port, max_retries)
    end

    def send_metric(name, timestamp, value, tags = {})
      tokens = [name, timestamp, value] + tags.flat_map { |key, tag_value| [key, tag_value] }
      unless tokens.all? { |part| part && /\A[^\s[:cntrl:]]+\z/.match?(part.to_s) }
        @logger.warn('Invalid TSDB metric')
        return
      end

      formatted_tags = tags.map { |tag| tag.join('=') }.sort.join(' ')
      command = "put #{name} #{timestamp} #{value} #{formatted_tags}\n"
      @logger.debug("[TSDB] >> #{command.chomp}")
      send_data(command)
    end
  end
end
