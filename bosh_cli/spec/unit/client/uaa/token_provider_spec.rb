require 'spec_helper'

describe Bosh::Cli::Client::Uaa::TokenProvider do
  include FakeFS::SpecHelpers

  subject(:token_provider) { described_class.new(auth_info, config, token_decoder, 'fake-target') }
  let(:config) { Bosh::Cli::Config.new('fake-config') }
  let(:auth_info) { Bosh::Cli::Client::Uaa::AuthInfo.new(director, env, 'fake-cert') }
  let(:env) { {} }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }
  let(:token_decoder) { Bosh::Cli::Client::Uaa::TokenDecoder.new }

  let(:client_token) do
    CF::UAA::TokenInfo.new(
      token_type: 'bearer',
      access_token: 'eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI2NzNiMGEzZS0yMWMwLTQ5YTQtOWU0OC03MDQzZDA'\
'3YzBjMjIiLCJzdWIiOiJ0ZXN0IiwiYXV0aG9yaXRpZXMiOlsidWFhLm5vbmUiXSwic2NvcGUiOlsidWFhLm5vbmUiX'\
'SwiY2xpZW50X2lkIjoidGVzdCIsImNpZCI6InRlc3QiLCJhenAiOiJ0ZXN0IiwiZ3JhbnRfdHlwZSI6ImNsaWVudF9'\
'jcmVkZW50aWFscyIsImlhdCI6MTQzMzI4ODQzMywiZXhwIjoxNDMzMjg5MDMzLCJpc3MiOiJodHRwczovLzEwLjI0N'\
'C4wLjIvb2F1dGgvdG9rZW4iLCJhdWQiOlsidGVzdCJdfQ.g4ke_2S3FWFN5dTPnVoxYgrqtSYmHBfw0FXFouf5Ruc'
    )
  end

  let(:invalid_token) do
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
    config.set_credentials('fake-target', { 'token' => token })
  end

  describe '#token' do
    context 'when client credentials are provided' do
      let(:env) do
        {
          'BOSH_CLIENT' => 'test',
          'BOSH_CLIENT_SECRET' => 'secret',
        }
      end

      context 'when token in config matches client credentials' do
        let(:token) { client_token.auth_header }

        it 'uses token in config' do
          expect(token_provider.token).to eq(token)
        end
      end

      context 'when token in config does not match client credentials' do
        let(:token) { invalid_token.auth_header }

        it 'logs in' do
          token_issuer = instance_double(CF::UAA::TokenIssuer)
          allow(CF::UAA::TokenIssuer).to receive(:new).and_return(token_issuer)
          allow(director).to receive(:get_status).and_return({'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'https://uaa-url'}}})
          expect(token_issuer).to receive(:client_credentials_grant).and_return(client_token)

          expect(token_provider.token).to eq(client_token.auth_header)
        end
      end
    end

    context 'when client credentials are not provided' do
      let(:token) { 'config-token' }

      it 'uses token from config' do
        expect(token_provider.token).to eq('config-token')
      end
    end
  end
end
