require 'logger'

class Bosh::Cpi::Logger < Logger

  def initialize(log_device)
    super(log_device)
  end

  def set_request_id(req_id)
    original_formatter = Logger::Formatter.new
    self.formatter = proc { |severity, datetime, progname, msg|
      original_formatter.call(severity, datetime, "[req_id #{req_id}]#{progname}", msg)
    }
  end
end