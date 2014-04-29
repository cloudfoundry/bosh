module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor
    def self.instrument(name, params = {}, &block)
      params = Bosh::OpenStackCloud::RedactedParams.new(params)
      cpi_log = Bosh::Clouds::Config.cloud_options["properties"]["cpi_log"]
      cpi_logger = Logger.new(cpi_log)
      cpi_logger.debug("#{name} #{params}")
      cpi_logger.close
      if block_given?
        yield
      end
    end
  end
end
