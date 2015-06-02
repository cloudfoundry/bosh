require 'cli/client/uaa/auth_info'
require 'cli/client/director'

describe Bosh::Cli::Client::Uaa::AuthInfo do
  subject(:auth_info) { described_class.new(director) }
  let(:director) { Bosh::Cli::Client::Director.new('http://127.0.0.1') }

  describe '#validate!' do
    it 'fails when url is not https' do
      allow(director).to receive(:get_status).and_return({'user_authentication' => {'type' => 'uaa', 'options' => {'url' => 'non-https-url'}}})
      expect do
        auth_info.validate!
      end.to raise_error Bosh::Cli::Client::Uaa::AuthInfo::ValidationError, 'HTTPS protocol is required'
    end
  end
end
