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

    def valid_access?(user, requested_access)
      @scope = requested_access

      if user.scopes
        required_scopes = required_scopes(requested_access)
        return @permission_authorizer.has_admin_or_director_scope?(user.scopes) ||
          @permission_authorizer.contains_requested_scope?(required_scopes, user.scopes)
      end
      false
    end

    def required_scopes(_)
      ['fake-valid-scope-1', 'fake-valid-scope-2']
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
