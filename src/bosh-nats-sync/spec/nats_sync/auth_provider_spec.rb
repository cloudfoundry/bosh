require 'spec_helper'
require 'rack/test'

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
      expect do
        auth_provider.auth_header
      end.to_not raise_error
    end
  end
end

describe NATSSync::AuthProvider do
  include Support::UaaHelpers

  subject(:auth_provider) { described_class.new(auth_info, config) }
  let(:user) { 'fake-user' }
  let(:password) { 'secret-password' }
  let(:config) do
    {
      'user' => user,
      'password' => password,
      'client_id' => 'fake-client',
      'client_secret' => 'fake-client-secret',
    }
  end

  context 'when director is in UAA mode' do
    let(:auth_info) do
      { 'user_authentication' => { 'type' => 'uaa', 'options' => { 'url' => 'uaa-url' } } }
    end
    let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

    let(:first_token) { uaa_token_info('first-token', expiration_time) }
    let(:second_token) { uaa_token_info('second-token', expiration_time) }
    let(:expiration_time) { Time.now.to_i + 3600 }

    before do
      allow(NATSSync).to receive(:logger).and_return(logger)
      allow(logger).to receive :error
    end

    let(:logger) { spy('Logger') }

    context 'user provides ca_cert' do
      before do
        config['ca_cert'] = 'fake-ca-cert-path'

        allow(File).to receive(:exist?).with('fake-ca-cert-path').and_return(true)
        allow(File).to receive(:read).with('fake-ca-cert-path').and_return('test')

        allow(CF::UAA::TokenIssuer).to receive(:new).with(
          'uaa-url', 'fake-client', 'fake-client-secret', ssl_ca_file: 'fake-ca-cert-path'
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
          'uaa-url', 'fake-client', 'fake-client-secret', ssl_cert_store: cert_store
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

    it 'returns Basic authentication string with username and password' do
      expect(auth_provider.auth_header).to eq(base64_user_password(user, password))
    end
  end

  private

  def base64_user_password (plain_user, plain_password)
    'Basic ' + Base64.encode64(plain_user.to_s + ':' + plain_password.to_s)
  end

end
