require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env, :roles

    def initialize(authenticates=true)
      @authenticates = authenticates
    end

    def corroborate_user(request_env, roles)
      @request_env = request_env
      @roles = roles
      raise Bosh::Director::AuthenticationError unless @authenticates
      'fake-user'
    end

    def client_info
      'fake-client-info'
    end
  end
end
