module Bosh::OpenStackCloud
  class ExconLoggingInstrumentor
    REDACTED = "[REDACTED]"
    def self.instrument(name, params = {}, &block)
      params = params.dup
      if params.has_key?(:headers) && params[:headers].has_key?('Authorization')
        params[:headers] = params[:headers].dup
        params[:headers]['Authorization'] = REDACTED
      end
      if params.has_key?(:password)
        params[:password] = REDACTED
      end
      Bosh::Clouds::Config.logger.debug("#{name}  #{params.inspect}")
      if block_given?
        yield
      end
    end
  end
end
