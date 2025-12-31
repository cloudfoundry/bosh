require 'bosh/director'

module Support
  class TestIdentityProvider
    attr_reader :request_env

    attr_accessor :scope

    def initialize(uuid_provider)
      @permission_authorizer = Bosh::Director::PermissionAuthorizer.new(uuid_provider)
      @uuid_provider = uuid_provider
    end

    def get_user(request_env, _)
      @request_env = request_env

      auth = Rack::Auth::Basic::Request.new(request_env)
      username = auth.credentials.first if auth
      password = auth.credentials[1] if auth
      if !username.nil? && username == password && user_scopes[username]
        client_id = client[username]
        TestUser.new(client_id ? nil : username, user_scopes[username], client_id)
      else
        raise Bosh::Director::AuthenticationError
      end
    end

    def client_info
      { 'type' => 'test-auth-type', 'stuff' => 'fake-client-info' }
    end

    private

    def user_scopes
      {
        'admin' => ['bosh.admin'],
        'client-username' => ['bosh.admin'],
        'reader' => ['bosh.read'],
        'director-reader' => ["bosh.#{@uuid_provider.uuid}.read"],
        'dev-team-member' => ['bosh.teams.dev.admin'],
        'dev-team-read-member' => ['bosh.teams.dev.read'],
        'dynamic-disks-updater' => ['bosh.dynamic_disks.update'],
        'dynamic-disks-deleter' => ['bosh.dynamic_disks.delete'],
        'outsider' => ['uaa.admin'],
      }
    end

    def client
      {'client-username' => 'client-id'}
    end
  end

  class TestUser
    attr_reader :username, :scopes, :client
    def initialize(username, scopes, client)
      @username = username
      @scopes = scopes
      @client = client
    end

    def username_or_client
      @username || @client
    end
  end
end
