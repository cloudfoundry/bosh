require 'cli/client/uaa/auth_info'
require 'cli/client/director'

describe Bosh::Cli::Client::Uaa::AuthInfo do
  subject(:auth_info) { described_class.new(director, {}, 'cert-file') }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }

  before do
    allow(director).to receive(:get_status).and_return({'user_authentication' => {'type' => 'uaa', 'options' => {'url' => uaa_url}}})
  end

  let(:uaa_url) { 'https://fake-url' }

  describe '#url' do
    it 'returns url' do
      expect(auth_info.url).to eq('https://fake-url')
    end

    context 'when url is not HTTPS' do
      let(:uaa_url) { 'http://fake-url' }

      it 'raises an error' do
        expect do
          auth_info.url
        end.to raise_error Bosh::Cli::Client::Uaa::AuthInfo::ValidationError, 'HTTPS protocol is required'
      end
    end

  end

  describe '#client_auth?' do
    it 'is true if both client id and secret are set' do
      options_with_id_and_secret = described_class.new(director, {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => 'some-client-secret'}, 'some-ca-cert-file')
      options_without_either = described_class.new(director, {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => nil}, 'some-ca-cert-file')

      expect(options_with_id_and_secret).to be_client_auth
      expect(options_without_either).to_not be_client_auth
    end

    it 'raises an error when only client_id is set' do
      options_without_secret = described_class.new(director, {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => nil}, 'some-ca-cert-file')

      expect {
        options_without_secret.client_auth?
      }.to raise_error(Bosh::Cli::Client::Uaa::AuthInfo::ValidationError, 'BOSH_CLIENT_SECRET is missing')
    end

    it 'raises an error when only client_secret is set' do
      options_without_id = described_class.new(director, {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => 'some-client-secret'}, 'some-ca-cert-file')

      expect {
        options_without_id.client_auth?
      }.to raise_error(Bosh::Cli::Client::Uaa::AuthInfo::ValidationError, 'BOSH_CLIENT is missing')
    end
  end
end
