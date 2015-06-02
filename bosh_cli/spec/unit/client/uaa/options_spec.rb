require 'cli/client/uaa/options'

describe Bosh::Cli::Client::Uaa::Options do
  describe '#client_auth?' do
    it 'is true if both client id and secret are set' do
      options_with_id_and_secret = Bosh::Cli::Client::Uaa::Options.new('some-ca-cert-file', {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => 'some-client-secret'})
      options_without_id = Bosh::Cli::Client::Uaa::Options.new('some-ca-cert-file', {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => 'some-client-secret'})
      options_without_secret = Bosh::Cli::Client::Uaa::Options.new('some-ca-cert-file', {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => nil})
      options_without_either = Bosh::Cli::Client::Uaa::Options.new('some-ca-cert-file', {'BOSH_CLIENT' => nil, 'BOSH_CLIENT_SECRET' => nil})

      expect(options_with_id_and_secret).to be_client_auth
      expect(options_without_id).to_not be_client_auth
      expect(options_without_secret).to_not be_client_auth
      expect(options_without_either).to_not be_client_auth
    end
  end
end
