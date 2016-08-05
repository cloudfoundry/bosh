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
    before do
      allow(token_issuer).to receive(:client_credentials_grant).and_raise(RuntimeError.new('failed'))
    end

    it 'logs an error' do
      expect(logger).to receive(:error).with(/failed/)

      expect {
        token_provider.auth_header
      }.to_not raise_error
    end
  end
end