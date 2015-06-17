require 'spec_helper'
require 'rack/test'

describe Bosh::Monitor::AuthProvider do
  include Support::UaaHelpers

  subject(:auth_provider) { described_class.new(auth_info, config, logger) }
  let(:config) do
    {
      'user' => 'fake-user',
      'password' => 'secret-password',
      'client_id' => 'fake-client',
      'client_secret' => 'fake-client-secret',
      'ca_cert' => 'fake-ca-cert'
    }
  end
  let(:logger) { double(:logger) }

  context 'when director is in UAA mode' do
    let(:auth_info) { {'user_authentication' => { 'type' => 'uaa', 'options' => {'url' => 'uaa-url'}} } }
    let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

    before do
      allow(CF::UAA::TokenIssuer).to receive(:new).with(
        'uaa-url', 'fake-client', 'fake-client-secret', { ssl_ca_file: 'fake-ca-cert' }
      ).and_return(token_issuer)
      allow(token_issuer).to receive(:client_credentials_grant).and_return(first_token, second_token)
    end

    let(:first_token) { uaa_token_info('first-token', expiration_time) }
    let(:second_token) { uaa_token_info('second-token', expiration_time) }
    let(:expiration_time) { Time.now.to_i + 3600 }

    it 'returns auth header provided by UAA' do
      expect(auth_provider.auth_header).to eq(first_token.auth_header)
    end

    it 'reuses the same token for subsequent requests' do
      expect(auth_provider.auth_header).to eq(first_token.auth_header)
      expect(auth_provider.auth_header).to eq(first_token.auth_header)
    end

    context 'when token is about to expire' do
      let(:expiration_time) { Time.now.to_i + 50 }

      it 'obtains new token' do
        expect(auth_provider.auth_header).to eq(first_token.auth_header)
        expect(auth_provider.auth_header).to eq(second_token.auth_header)
      end
    end

    context 'when getting token fails' do
      before do
        allow(token_issuer).to receive(:client_credentials_grant).and_raise(RuntimeError.new('failed'))
      end

      it 'logs an error' do
        expect(logger).to receive(:error).with(/failed/)

        expect {
          auth_provider.auth_header
        }.to_not raise_error
      end
    end
  end

  context 'when director is in non-UAA mode' do
    let(:auth_info) { {} }

    it 'returns username and password' do
      expect(auth_provider.auth_header).to eq(['fake-user', 'secret-password'])
    end
  end
end
