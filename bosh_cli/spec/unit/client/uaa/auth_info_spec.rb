require 'cli/client/uaa/auth_info'
require 'cli/client/director'

describe Bosh::Cli::Client::Uaa::AuthInfo do
  subject(:auth_info) { described_class.new(director, {}, 'cert-file') }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }

  describe '#url' do
    before do
      allow(director).to receive(:get_status).and_return({'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'non-https-url'}}})
    end

    context 'when it is not HTTPS' do
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
      options_without_id = described_class.new(director, {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => 'some-client-secret'}, 'some-ca-cert-file')
      options_without_secret = described_class.new(director, {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => nil}, 'some-ca-cert-file')
      options_without_either = described_class.new(director, {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => nil}, 'some-ca-cert-file')

      expect(options_with_id_and_secret).to be_client_auth
      expect(options_without_id).to_not be_client_auth
      expect(options_without_secret).to_not be_client_auth
      expect(options_without_either).to_not be_client_auth
    end
  end
end
