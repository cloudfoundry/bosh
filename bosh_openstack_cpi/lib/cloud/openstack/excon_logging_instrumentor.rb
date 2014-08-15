module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor
    def self.instrument(name, params = {}, &block)
      params = Bosh::OpenStackCloud::RedactedParams.new(params)
      Bosh::Clouds::Config.logger.debug("#{name} #{params}")
      cpi_logger = Logger.new(Bosh::Clouds::Config.cpi_task_log)
      cpi_logger.debug("#{name} #{params}")
      cpi_logger.close
      if block_given?
        yield
      end
    end
  end
end
