require 'spec_helper'

describe Bosh::Cli::Client::Uaa::Client do
  include FakeFS::SpecHelpers
  include Support::UaaHelpers

  subject(:client) { described_class.new('fake-target', auth_info, config) }
  let(:auth_info) { Bosh::Cli::Client::Uaa::AuthInfo.new(director, env, 'fake-cert') }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }
  let(:env) { {} }
  let(:config) { Bosh::Cli::Config.new('fake-config') }

  let(:password_token) do
    uaa_token_info('bosh_cli', uaa_token_expiration_time, 'password-refresh-token')
  end

  let(:client_token) do
    uaa_token_info('fake-client', uaa_token_expiration_time, nil)
  end

  let(:refreshed_token) do
    CF::UAA::TokenInfo.new(
      token_type: 'bearer',
      access_token: 'refreshed-token',
      refresh_token: 'fake-new-refresh-token'
    )
  end

  let(:access_info) { Bosh::Cli::Client::Uaa::PasswordAccessInfo.new(password_token, double('token-decoder')) }

  before do
    allow(director).to receive(:get_status).and_return(
      {'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'https://uaa-url'}}}
    )
    allow(CF::UAA::TokenIssuer).to receive(:new).and_return(token_issuer)
    allow(token_issuer).to receive(:owner_password_credentials_grant).and_return(password_token)
    allow(token_issuer).to receive(:client_credentials_grant).and_return(client_token)
    allow(token_issuer).to receive(:refresh_token_grant).with('password-refresh-token').and_return(refreshed_token)
  end

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

  describe '#access_info' do
    it 'gets access info from token issuer' do
      access_info = client.access_info({})
      expect(access_info.auth_header).to eq(password_token.auth_header)
    end

    context 'when using client auth' do
      let(:env) { { 'BOSH_CLIENT' => 'fake-client', 'BOSH_CLIENT_SECRET' => 'client_secret' } }

      it 'does not save token in config' do
        client.access_info({})
        config = YAML.load(File.read('fake-config'))
        expect(config['auth']).to eq(nil)
      end
    end

    context 'when using password auth' do
      it 'saves token in config' do
        client.access_info({})
        config = YAML.load(File.read('fake-config'))
        expect(config['auth']['fake-target']['access_token']).to eq(password_token.auth_header)
        expect(config['auth']['fake-target']['refresh_token']).to eq('password-refresh-token')
      end
    end
  end

  describe '#refresh' do
    it 'gets access info from token issuer' do
      refreshed_access_info = client.refresh(access_info)
      expect(refreshed_access_info.auth_header).to eq(refreshed_token.auth_header)
    end

    it 'does not save token in config' do
      client.refresh(access_info)
      config = YAML.load(File.read('fake-config'))
      expect(config['auth']).to be_nil
    end

    context 'when failing to get access token' do
      before do
        allow(token_issuer).to receive(:refresh_token_grant).with('password-refresh-token').and_raise(CF::UAA::TargetError)
      end

      it 'returns nil' do
        expect(client.refresh(access_info)).to eq(nil)
      end
    end
  end
end
