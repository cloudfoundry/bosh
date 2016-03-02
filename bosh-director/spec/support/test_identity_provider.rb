require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env

    attr_accessor :scope

    def initialize
      @has_access = false
      @permission_authorizer = Bosh::Director::PermissionAuthorizer.new
    end

    def get_user(request_env, _)
      @request_env = request_env

      auth = Rack::Auth::Basic::Request.new(request_env)
      username = auth.credentials.first if auth
      password = auth.credentials[1] if auth
      if !username.nil? && username == password && user_scopes[username]
        TestUser.new(username, user_scopes[username])
      else
        raise Bosh::Director::AuthenticationError
      end
    end

    def client_info
      'fake-client-info'
    end

    private

    def user_scopes
      {
        'admin' => ['bosh.admin'],
        'reader' => ['bosh.read'],
        'dev-team-member' => ['bosh.teams.dev.admin'],
        'dev-team-read-member' => ['bosh.teams.dev.read']
      }
    end

  end

  class TestUser
    attr_reader :username, :scopes
    def initialize(username, scopes)
      @username = username
      @scopes = scopes
    end
  end
end
