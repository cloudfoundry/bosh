require 'spec_helper'

describe Bosh::Cli::Command::Base do
  before do
    @runner = double(Bosh::Cli::Runner)
    @config_file = File.join(Dir.mktmpdir, 'bosh_config')
  end

  def add_config(object)
    File.open(@config_file, 'w') do |f|
      f.write(Psych.dump(object))
    end
  end

  def make
    cmd = Bosh::Cli::Command::Base.new(@runner)
    cmd.add_option(:config, @config_file)
    cmd
  end

  before { stub_request(:get, "#{target}/info").to_return(body: '{}') }

  let(:target) { 'https://127.0.0.1:8080' }

  it 'can access configuration and respects options' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh', 'deployment' => 'test')

    cmd = make
    expect(cmd.config).to be_a(Bosh::Cli::Config)

    expect(cmd.target).to eq('https://localhost:8080')
    expect(cmd.target_name).to eq('microbosh')
    expect(cmd.deployment).to eq('test')
    expect(cmd.credentials).to be_nil
  end

  it 'respects target option' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh')

    cmd = make
    cmd.add_option(:target, 'new-target')

    expect(cmd.target).to eq('https://new-target:25555')
    expect(cmd.target_name).to eq('new-target')
  end

  it 'instantiates director when needed' do
    add_config('target' => 'localhost:8080', 'deployment' => 'test')

    cmd = make
    expect(cmd.director).to be_kind_of(Bosh::Cli::Client::Director)
    expect(cmd.director.director_uri).to eq(URI.parse('https://localhost:8080'))
  end

  it 'has logged_in? helper' do
    add_config('target' => target, 'deployment' => 'test')

    cmd = make
    expect(cmd.logged_in?).to be(false)
    cmd.add_option(:username, 'foo')
    expect(cmd.logged_in?).to be(false)
    cmd.add_option(:password, 'bar')
    expect(cmd.logged_in?).to be(true)
  end

  it 'gives the max_parallel_downloads options to the blob manager' do
    allow(Bosh::Cli::BlobManager).to receive(:new)
    max_parallel_downloads = double(:max_parallel_downloads)
    release = double(:release)
    Bosh::Cli::Config.max_parallel_downloads = max_parallel_downloads
    cmd = make
    allow(cmd).to receive(:release).and_return(release)

    cmd.blob_manager
    expect(Bosh::Cli::BlobManager).to have_received(:new).with(release, max_parallel_downloads, anything)
    Bosh::Cli::Config.max_parallel_downloads = nil
  end

  context 'target' do
    context 'when port 443 is specified' do
      it 'persists the port within the target' do
        cmd = make
        cmd.add_option(:target, 'https://foo:443')
        expect(cmd.target).to eq('https://foo:443')
      end
    end

    context 'when port 443 is specified' do
      it 'persists the port within the target' do
        cmd = make
        cmd.add_option(:target, 'https://foo:25555')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end

    context 'when a trailing slash is provided' do
      it 'strips the trailing slash' do
        cmd = make
        cmd.add_option(:target, 'https://foo/')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end

    context 'when no scheme is provided' do
      it 'adds https as the default scheme' do
        cmd = make
        cmd.add_option(:target, 'foo')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end
  end

  describe 'cache_dir' do
    it 'defaults to $HOME/.bosh/cache' do
      allow(Dir).to receive(:home).and_return('/fake/home/dir')
      expect(make.cache_dir).to eq('/fake/home/dir/.bosh/cache')
    end
  end

  describe 'credentials' do
    include Support::UaaHelpers

    context 'when configured in UAA mode' do
      before do
        director_status = {'user_authentication' => {
          'type' => 'uaa',
          'options' => {'url' => 'https://127.0.0.1:8080/uaa'}
        }}
        stub_request(:get, 'https://127.0.0.1:8080/info').to_return(body: JSON.dump(director_status))
      end

      context 'when client credentials are provided in environment' do
        let(:cmd) do
          add_config('target' => 'localhost:8080')
          make
        end
        let(:env) do
          {
            'BOSH_CLIENT' => 'fake-id',
            'BOSH_CLIENT_SECRET' => 'secret'
          }
        end
        before do
          stub_const('ENV', env)
          allow(CF::UAA::TokenIssuer).to receive(:new).and_return(token_issuer)
        end

        let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }
        let(:token) { uaa_token_info('fake-id', expiration_time, nil) }
        let(:expiration_time) { Time.now.to_i + expiration_deadline + 10 }
        let(:expiration_deadline) { Bosh::Cli::Client::Uaa::AccessInfo::EXPIRATION_DEADLINE_IN_SECONDS }

        it 'reuses the same token for client credentials if it is valid' do
          expect(token_issuer).to receive(:client_credentials_grant).once.and_return(token)

          expect(cmd.credentials.authorization_header).to eq(token.auth_header)
          expect(cmd.credentials.authorization_header).to eq(token.auth_header)
        end
      end

      context 'when config contains UAA token' do
        let(:cmd) do
          add_config(
            'target' => 'localhost:8080',
            'auth' => {
              'https://localhost:8080' => {
                'access_token' => token_info.auth_header,
              }
            })
          make
        end

        let(:token_info) do
          uaa_token_info('fake-id', Time.now.to_i + 3600, 'refresh-token')
        end

        it 'returns UAA credentials' do
          expect(cmd.credentials.authorization_header).to eq(token_info.auth_header)
        end
      end
    end

    context 'when configured in basic authentication mode' do
      let(:cmd) do
        add_config(
          'target' => 'localhost:8080',
          'auth' => {
            'https://localhost:8080' => {
              'username' => 'config-username',
              'password' => 'config-password',
            }
          })
        make
      end

      let(:authorization_header) { 'Basic ' + Base64.encode64("#{expected_username}:#{expected_password}").strip }
      let(:expected_username) { 'config-username' }
      let(:expected_password) { 'config-password' }

      context 'when user provided username option' do
        let(:expected_username) { 'option-username' }
        before { cmd.add_option(:username, expected_username) }

        it 'returns basic credentials with provided username' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided password option' do
        let(:expected_password) { 'option-password' }
        before { cmd.add_option(:password, expected_password) }

        it 'returns basic credentials with provided password' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided BOSH_USER env variable' do
        let(:expected_username) { 'env-username' }
        before { stub_const('ENV', {'BOSH_USER' => 'env-username'}) }

        it 'returns basic credentials with provided username' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided BOSH_PASSWORD env variable' do
        let(:expected_password) { 'env-password' }
        before { stub_const('ENV', {'BOSH_PASSWORD' => expected_password}) }

        it 'returns basic credentials with provided password' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when credentials are not provided in config' do
        let(:cmd) do
          add_config('target' => 'localhost:8080')
          make
        end

        it 'returns nil' do
          expect(cmd.credentials).to be_nil
        end
      end

      context 'when target is not set' do
        let(:cmd) { make }

        it 'fails' do
          expect { cmd.credentials }.to raise_error
        end
      end
    end
  end

  describe 'show_current_state' do
    context 'when command requires authentication' do
      class TestCommand < Bosh::Cli::Command::Base
        def initialize(runner, deployment_name = nil, client_auth = false)
          @deployment_name = deployment_name
          @client_auth = client_auth
          super(runner)
        end

        def run
          show_current_state(@deployment_name)
        end

        def credentials
          Bosh::Cli::Client::BasicCredentials.new('fake-user', 'fake-password')
        end

        def auth_info
          env = {}

          if @client_auth
            env = {
              'BOSH_CLIENT' => 'fake-client',
              'BOSH_CLIENT_SECRET' => 'fake-client-secret'
            }
          end

          Bosh::Cli::Client::Uaa::AuthInfo.new('fake-director', env, 'fake-ssl-file')
        end
      end

      let(:cmd) do
        cmd = TestCommand.new(@runner, 'fake-deployment', client_auth)
        cmd.options[:target] = 'fake-target'
        cmd
      end
      let(:client_auth) { false }

      it 'prints current user, deployment and target' do
        expect(cmd).to receive(:warn).with("Acting as user 'fake-user' on deployment 'fake-deployment' on 'fake-target'")
        cmd.run
      end

      context 'when deployment name is not present' do
        let(:cmd) do
          cmd = TestCommand.new(@runner)
          cmd.options[:target] = 'fake-target'
          cmd
        end

        it 'does not report the deployment' do
          expect(cmd).to receive(:warn).with("Acting as user 'fake-user' on 'fake-target'")
          cmd.run
        end
      end

      context 'when logged in as client' do
        let(:client_auth) { true }

        it 'reports client name' do
          expect(cmd).to receive(:warn).with("Acting as client 'fake-user' on deployment 'fake-deployment' on 'fake-target'")
          cmd.run
        end
      end
    end
  end
end
