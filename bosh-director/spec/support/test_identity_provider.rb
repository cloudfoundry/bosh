require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env, :scope

    def initialize(authenticates=true)
      @authenticates = authenticates
    end

    def corroborate_user(request_env, scope)
      @request_env = request_env
      @scope = scope
      raise Bosh::Director::AuthenticationError unless @authenticates
      'fake-user'
    end

    def client_info
      'fake-client-info'
    end
  end
end
