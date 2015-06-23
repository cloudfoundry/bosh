require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env

    attr_accessor :scope

    def initialize(authenticates=true)
      @authenticates = authenticates
    end

    def get_user(request_env)
      @request_env = request_env
      raise Bosh::Director::AuthenticationError unless @authenticates
      TestUser.new('fake-user', self)
    end

    def client_info
      'fake-client-info'
    end
  end

  class TestUser

    attr_reader :username

    def initialize(username, identity_provider)
      @username = username
      @identity_provider = identity_provider
    end

    def has_access?(scope)
      @identity_provider.scope = scope
      true
    end
  end
end
