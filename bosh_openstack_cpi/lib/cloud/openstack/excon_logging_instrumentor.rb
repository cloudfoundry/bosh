module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor
    def self.instrument(name, params = {}, &block)
      params = Bosh::OpenStackCloud::RedactedParams.new(params)
      Bosh::Clouds::Config.logger.debug("#{name} #{params}")
      if block_given?
        yield
      end
    end
  end
end
