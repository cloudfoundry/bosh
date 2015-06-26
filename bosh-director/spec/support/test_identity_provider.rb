require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env

    attr_accessor :scope, :user_access

    def initialize
      @has_access = false
    end

    def get_user(request_env)
      @request_env = request_env

      auth = Rack::Auth::Basic::Request.new(request_env)
      username = auth.credentials.first if auth
      if !username.nil? && user_access[username]
        TestUser.new(username)
      else
        raise Bosh::Director::AuthenticationError
      end
    end

    def client_info
      'fake-client-info'
    end

    def valid_access?(user, requested_access)
      @scope = requested_access
      user_access[user.username] == requested_access
    end

    def required_scopes(_)
      ['fake-valid-scope-1', 'fake-valid-scope-2']
    end

    private

    def user_access
      {
        'admin' => :write,
        'reader' => :read
      }
    end

  end

  class TestUser < Struct.new(:username); end
end
