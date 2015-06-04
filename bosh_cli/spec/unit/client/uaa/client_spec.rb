require 'spec_helper'

describe Bosh::Cli::Client::Uaa::Client do
  include FakeFS::SpecHelpers

  subject(:client) { described_class.new('fake-target', auth_info, config) }
  let(:auth_info) { Bosh::Cli::Client::Uaa::AuthInfo.new(director, {}, 'fake-cert') }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }
  let(:config) { Bosh::Cli::Config.new('fake-config') }

  let(:password_token) do
    CF::UAA::TokenInfo.new(
      token_type: 'bearer',
      access_token: 'eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI2OTg1MjgzNi05ZjhkLTRkNzctYTA1OC1iMGZlNmV'\
'kMGM0ZWQiLCJzdWIiOiI3ZWQ4ZmRlYS1iNWJiLTRkMWUtYmJhOC1jMDMyNDM4MGY2NWIiLCJzY29wZSI6WyJvcGVuaWQ'\
'iXSwiY2xpZW50X2lkIjoiYm9zaF9jbGkiLCJjaWQiOiJib3NoX2NsaSIsImF6cCI6ImJvc2hfY2xpIiwiZ3JhbnRfdHl'\
'wZSI6InBhc3N3b3JkIiwidXNlcl9pZCI6IjdlZDhmZGVhLWI1YmItNGQxZS1iYmE4LWMwMzI0MzgwZjY1YiIsInVzZXJ'\
'fbmFtZSI6ImFkbWluIiwiZW1haWwiOiJhZG1pbiIsImlhdCI6MTQzMzI4OTIxMiwiZXhwIjoxNDMzMzMyNDEyLCJpc3M'\
'iOiJodHRwczovLzEwLjI0NC4wLjIvb2F1dGgvdG9rZW4iLCJhdWQiOlsiYm9zaF9jbGkiLCJvcGVuaWQiXX0.UM8SBWE'\
'yT10XVKeuMF9GT1P4iBsFEs-q22xr2vsS1SM',
      refresh_token: 'fake-refresh-token'
    )
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
    allow(token_issuer).to receive(:refresh_token_grant).with('fake-refresh-token').and_return(refreshed_token)
  end

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

  describe '#access_info' do
    it 'gets access info from token issuer' do
      access_info = client.access_info({})
      expect(access_info.auth_header).to eq(password_token.auth_header)
    end

    it 'saves token in config' do
      client.access_info({})
      config = YAML.load(File.read('fake-config'))
      expect(config['auth']['fake-target']['access_token']).to eq(password_token.auth_header)
      expect(config['auth']['fake-target']['refresh_token']).to eq('fake-refresh-token')
    end
  end

  describe '#refresh' do
    it 'gets access info from token issuer' do
      refreshed_access_info = client.refresh(access_info)
      expect(refreshed_access_info.auth_header).to eq(refreshed_token.auth_header)
    end

    it 'saves token in config' do
      client.refresh(access_info)
      config = YAML.load(File.read('fake-config'))
      expect(config['auth']['fake-target']['access_token']).to eq(refreshed_token.auth_header)
      expect(config['auth']['fake-target']['refresh_token']).to eq('fake-new-refresh-token')
    end

    context 'when failing to get access token' do
      before do
        allow(token_issuer).to receive(:refresh_token_grant).with('fake-refresh-token').and_raise(CF::UAA::TargetError)
      end

      it 'returns nil' do
        expect(client.refresh(access_info)).to eq(nil)
      end
    end
  end
end
