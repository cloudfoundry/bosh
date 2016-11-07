require 'spec_helper'
require 'rack/test'

describe Bosh::Director::UAAAuthProvider do
  include Support::UaaHelpers

  subject(:token_provider) { described_class.new(config, logger) }
  let(:config) do
    {
        'client_id' => 'fake-client',
        'client_secret' => 'fake-client-secret',
        'url' => 'fake-uaa-url',
        'ca_cert_path' => 'fake-ca-cert-path'
    }
  end
  let(:logger) { double(:logger) }

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

  let(:first_token) { uaa_token_info('first-token', expiration_time) }
  let(:second_token) { uaa_token_info('second-token', expiration_time) }
  let(:expiration_time) { Time.now.to_i + 3600 }

  before do
    allow(File).to receive(:exist?).with('fake-ca-cert-path').and_return(true)
    allow(File).to receive(:read).with('fake-ca-cert-path').and_return('test')

    allow(CF::UAA::TokenIssuer).to receive(:new).with(
        'fake-uaa-url', 'fake-client', 'fake-client-secret', { :ssl_ca_file => 'fake-ca-cert-path' }
    ).and_return(token_issuer)
    allow(token_issuer).to receive(:client_credentials_grant).and_return(first_token, second_token)
  end

  it 'returns auth header provided by UAA' do
    expect(token_provider.auth_header).to eq(first_token.auth_header)
  end

  it 'reuses the same token for subsequent requests' do
    expect(token_provider.auth_header).to eq(first_token.auth_header)
    expect(token_provider.auth_header).to eq(first_token.auth_header)
  end

  context 'when token is about to expire' do
    let(:expiration_time) { Time.now.to_i + 50 }

    it 'obtains new token' do
      expect(token_provider.auth_header).to eq(first_token.auth_header)
      expect(token_provider.auth_header).to eq(second_token.auth_header)
    end
  end

  context 'when getting token fails' do

    let(:client_credentials_grant_error) {RuntimeError.new('failed')}

    before do
      allow(token_issuer).to receive(:client_credentials_grant).and_raise(client_credentials_grant_error)
      allow(logger).to receive(:error)
    end

    it 'logs an error' do
      expect(logger).to receive(:error).with("Failed to obtain valid token from UAA: #{client_credentials_grant_error.inspect}")
      expect {
        token_provider.auth_header
      }.to raise_error
    end

    it 'raises UAAAuthorizationError' do
      expect {
        token_provider.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: #{client_credentials_grant_error.inspect}")
    end
  end

  context 'when decoding token fails' do

    let(:decode_error) {RuntimeError.new('failed')}

    before do
      allow(CF::UAA::TokenCoder).to receive(:decode).and_raise(decode_error)
      allow(logger).to receive(:error)
    end

    it 'logs an error' do
      expect(logger).to receive(:error).with("Failed to obtain valid token from UAA: #{decode_error.inspect}")
      expect {
        token_provider.auth_header
      }.to raise_error
    end

    it 'raises UAAAuthorizationError' do
      expect {
        token_provider.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: #{decode_error.inspect}")
    end
  end

end