require 'spec_helper'

describe Bosh::Cli::Client::Uaa do
  subject(:uaa) { described_class.new({ 'url' => url }, 'fake-ca-cert') }
  let(:url) { 'https://example.com' }
  before do
    allow(CF::UAA::TokenIssuer).to receive(:new).
        with(url, 'bosh_cli', nil, { ssl_ca_file: 'fake-ca-cert' }).
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
end
