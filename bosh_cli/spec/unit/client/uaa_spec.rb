require 'spec_helper'

describe Bosh::Cli::Client::Uaa do
  subject(:uaa) { described_class.new({ 'url' => url }, ca_cert) }
  let(:ca_cert) { 'fake-ca-cert' }
  let(:url) { 'https://example.com' }
  before do
    allow(CF::UAA::TokenIssuer).to receive(:new).
        with(url, 'bosh_cli', nil, { ssl_ca_file: ca_cert }).
        and_return(token_issuer)
  end

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

  describe '#initialize' do
    context 'when URL is not HTTPS' do
      let(:url) { 'http://example.com' }

      it 'fails' do
        expect { uaa }.to raise_error /HTTPS protocol is required/
      end
    end
  end

  describe '#login' do
    context 'when login succeeds' do
      before do
        token = instance_double(
          CF::UAA::TokenInfo,
          info: {
            'access_token' => 'fake-token',
            'token_type' => 'bearer'
          }
        )
        allow(CF::UAA::TokenCoder).to receive(:decode).
            with('fake-token', { verify: false }, nil, nil).
            and_return({'user_name' => 'fake-user'})
        allow(token_issuer).to receive(:implicit_grant_with_creds).
            with('fake-credentials').
            and_return(token)
      end

      it 'returns a token' do
        expect(uaa.login('fake-credentials')).to eq({username: 'fake-user', token: 'bearer fake-token'})
      end
    end

    context 'for an invalid login' do
      before do
        allow(token_issuer).to receive(:implicit_grant_with_creds).
            with('fake-credentials').
            and_raise(CF::UAA::BadResponse)
      end

      it 'returns nil' do
        expect(uaa.login('fake-credentials')).to be_nil
      end
    end
  end

  describe '#prompts' do
    context 'when getting prompts fails with ssl error' do
      before { allow(token_issuer).to receive(:prompts).and_raise(ssl_error) }
      let(:ssl_error) { CF::UAA::SSLException.new('ssl-error') }

      context 'when ca-cert is not provided' do
        let(:ca_cert) { nil }

        it 'suggests to specify certificate' do
          expect {
            uaa.prompts
          }.to raise_error /Invalid SSL Cert. Use --ca-cert to specify SSL certificate/
        end
      end

      context 'when ca-cert is provided' do
        it 'raises original error' do
          expect {
            uaa.prompts
          }.to raise_error ssl_error
        end
      end
    end
  end
end
