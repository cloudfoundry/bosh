require 'spec_helper'
require 'rack/test'
require 'httpclient'

describe Bosh::Director::ConfigServer::UAAAuthProvider do
  include Support::UaaHelpers

  subject { described_class.new(config, logger) }
  let(:uaa_url) {'https://fake-uaa-url'}
  let(:config) do
    {
        'client_id' => 'fake-client',
        'client_secret' => 'fake-client-secret',
        'url' => uaa_url,
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
      uaa_url, 'fake-client', 'fake-client-secret', { :ssl_ca_file => 'fake-ca-cert-path' }
    ).and_return(token_issuer)
    allow(token_issuer).to receive(:client_credentials_grant).and_return(first_token, second_token)
  end

  context '#get_token' do
    it 'returns a new uaa token' do
      expect(Bosh::Director::ConfigServer::UAAToken).to receive(:new).exactly(2).times
      subject.get_token
      subject.get_token
    end
  end

  let(:token) { subject.get_token }
  context 'when getting token fails' do

    let(:client_credentials_grant_error) {RuntimeError.new('failed')}

    before do
      allow(token_issuer).to receive(:client_credentials_grant).and_raise(client_credentials_grant_error)
      allow(logger).to receive(:error)
    end

    it 'logs an error' do
      expect(logger).to receive(:error).with("Failed to obtain valid token from UAA: #{client_credentials_grant_error.inspect}")
      expect {
        token.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, /Failed to obtain valid token from UAA: .+ failed/)
    end

    it 'raises UAAAuthorizationError' do
      expect {
        token.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: #{client_credentials_grant_error.inspect}")
    end

    context 'when error is CF::UAA::SSLException' do
      let(:client_credentials_grant_error) do
        CF::UAA::SSLException.new("Invalid SSL Cert for #{uaa_url}. Use '--skip-ssl-validation' to continue with an insecure target")
      end

      it 'catches the error and provide more user friendly error message' do
        expect {
          token.auth_header
        }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: Invalid SSL Cert for '#{uaa_url}'")
      end
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
        token.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, /Failed to obtain valid token from UAA: .+ failed/)
    end

    it 'raises UAAAuthorizationError' do
      expect {
        token.auth_header
      }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: #{decode_error.inspect}")
    end
  end

  context 'should gracefully handle connection errors' do
    context 'when getting token fails due to a connection error' do
      let(:client_credentials_grant_error) {Errno::ECONNREFUSED.new('')}
      before do
        allow(token_issuer).to receive(:client_credentials_grant).and_raise(client_credentials_grant_error)
        allow(logger).to receive(:error)
      end

      it 'raises the exception after trying 3 times' do
        expect(token_issuer).to receive(:client_credentials_grant).exactly(3).times
        expect {
          token.auth_header
        }.to raise_error(Bosh::Director::UAAAuthorizationError, "Failed to obtain valid token from UAA: #{client_credentials_grant_error.inspect}")
      end
    end

    context 'when getting token fails due to a connection error and then recovers on a subsequent retry' do
      let(:client_credentials_grant_error) {Errno::ECONNREFUSED.new('')}
      before do
        count = 0
        allow(token_issuer).to receive(:client_credentials_grant) do
          count += 1
          if count < 3
            raise client_credentials_grant_error
          end
          first_token
        end
        allow(logger).to receive(:error)
      end

      it 'does NOT raise an exception' do
        expect(token_issuer).to receive(:client_credentials_grant).exactly(3).times
        expect {
          token.auth_header
        }.to_not raise_error
      end
    end

    it 'sets the appropriate exceptions to handle on retryable' do
      handled_exceptions = [
          SocketError,
          Errno::ECONNREFUSED,
          Errno::ETIMEDOUT,
          Errno::ECONNRESET,
          Timeout::Error,
          HTTPClient::TimeoutError,
          HTTPClient::KeepAliveDisconnected,
          OpenSSL::SSL::SSLError
      ]

      retryable = double("Bosh::Retryable")
      allow(retryable).to receive(:retryer).and_return(first_token)

      allow(Bosh::Retryable).to receive(:new).with({sleep:0, tries: 3, on: handled_exceptions}).and_return(retryable)

      allow(logger).to receive(:error)
      token.auth_header
    end
  end
end
