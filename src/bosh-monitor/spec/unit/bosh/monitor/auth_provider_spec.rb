require 'spec_helper'

shared_examples :auth_provider_shared_tests do
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

      expect do
        auth_provider.auth_header
      end.to_not raise_error
    end
  end
end

describe Bosh::Monitor::AuthProvider do
  include Support::UaaHelpers

  subject(:auth_provider) { described_class.new(auth_info, config, logger) }
  let(:config) do
    {
      'user' => 'fake-user',
      'password' => 'secret-password',
      'client_id' => 'fake-client',
      'client_secret' => 'fake-client-secret',
    }
  end
  let(:logger) { double(:logger) }

  context 'when director is in UAA mode' do
    let(:auth_info) do
      { 'user_authentication' => { 'type' => 'uaa', 'options' => { 'url' => 'uaa-url' } } }
    end
    let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

    let(:first_token) { uaa_token_info('first-token', expiration_time) }
    let(:second_token) { uaa_token_info('second-token', expiration_time) }
    let(:expiration_time) { Time.now.to_i + 3600 }

    context 'user provides ca_cert' do
      before do
        config['ca_cert'] = 'fake-ca-cert-path'

        allow(File).to receive(:exist?).with('fake-ca-cert-path').and_return(true)
        allow(File).to receive(:read).with('fake-ca-cert-path').and_return('test')

        allow(CF::UAA::TokenIssuer).to receive(:new).with(
          'uaa-url', 'fake-client', 'fake-client-secret', { ssl_ca_file: 'fake-ca-cert-path' }
        ).and_return(token_issuer)
        allow(token_issuer).to receive(:client_credentials_grant).and_return(first_token, second_token)
      end

      it_behaves_like :auth_provider_shared_tests
    end

    context 'user has not provided ca_cert' do
      let(:cert_store) { instance_double(OpenSSL::X509::Store) }

      before do
        allow(OpenSSL::X509::Store).to receive(:new).and_return(cert_store)
        allow(cert_store).to receive(:set_default_paths)
        allow(CF::UAA::TokenIssuer).to receive(:new).with(
          'uaa-url', 'fake-client', 'fake-client-secret', { ssl_cert_store: cert_store }
        ).and_return(token_issuer)
        allow(token_issuer).to receive(:client_credentials_grant).and_return(first_token, second_token)
      end

      it_behaves_like :auth_provider_shared_tests
    end
  end

  context 'when director is in non-UAA mode' do
    let(:auth_info) do
      {}
    end

    it 'returns the basic-auth header with encoded username and password' do
      expect(auth_provider.auth_header).to eq('Basic ZmFrZS11c2VyOnNlY3JldC1wYXNzd29yZA==')
    end
  end
end
