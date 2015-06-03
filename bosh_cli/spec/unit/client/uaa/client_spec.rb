require 'spec_helper'

describe Bosh::Cli::Client::Uaa::Client do
  include FakeFS::SpecHelpers

  subject(:client) { described_class.new(auth_info, config) }
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
'yT10XVKeuMF9GT1P4iBsFEs-q22xr2vsS1SM'
    )
  end

  before do
    allow(director).to receive(:get_status).and_return(
      {'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'https://uaa-url'}}}
    )
    token_issuer = instance_double(CF::UAA::TokenIssuer)
    allow(CF::UAA::TokenIssuer).to receive(:new).and_return(token_issuer)
    allow(token_issuer).to receive(:owner_password_credentials_grant).and_return(password_token)
  end

  describe '#login' do
    it 'gets access info from token issuer' do
      access_info = client.login({}, 'fake-target')
      expect(access_info.auth_header).to eq(password_token.auth_header)
    end

    it 'saves token in config' do
      client.login({}, 'fake-target')
      config = YAML.load(File.read('fake-config'))
      expect(config['auth']['fake-target']['token']).to eq(password_token.auth_header)
    end
  end
end
