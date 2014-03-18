module Bosh::OpenStackCloud
  class RedactedParams
    REDACTED = "[REDACTED]"

    def initialize(params)
      @params = params
      redact_authorization_params
      redact_password_params
    end

    def to_s
      @params.inspect
    end

    private

    def redact_authorization_params
      if @params.has_key?(:headers) && @params[:headers].has_key?('Authorization')
        @params[:headers]['Authorization'] = REDACTED
      end
    end

    def redact_password_params
      if @params.has_key?(:password)
        @params[:password] = REDACTED
      end
    end
  end
end
