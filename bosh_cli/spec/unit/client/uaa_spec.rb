require 'spec_helper'

describe Bosh::Cli::Client::Uaa do
  subject(:uaa) { described_class.new({'url' => 'fake-url'}) }
  before do
    allow(CF::UAA::TokenIssuer).to receive(:new).
        with('fake-url', 'bosh_cli', nil, {skip_ssl_validation: true}).
        and_return(token_issuer)
  end

  let(:token_issuer) { instance_double(CF::UAA::TokenIssuer) }

  describe '#login' do
    context 'when login succeeds' do
      before do
        token = instance_double(
          CF::UAA::TokenInfo,
          info: {
            'access_token' => 'fake-token',
          }
        )
        allow(CF::UAA::TokenCoder).to receive(:decode).
            with('fake-token', {}, nil, false).
            and_return({'user_name' => 'fake-user'})
        allow(token_issuer).to receive(:implicit_grant_with_creds).
            with('fake-credentials').
            and_return(token)
      end

      it 'returns a token' do
        expect(uaa.login('fake-credentials')).to eq({username: 'fake-user', token: 'fake-token'})
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
