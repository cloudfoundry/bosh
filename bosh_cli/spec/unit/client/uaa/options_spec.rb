require 'cli/client/uaa/options'

describe Bosh::Cli::Client::Uaa::Options do
  describe '#parse' do
    it 'parses url from auth options, cert from cli options, client id and secret from the env' do
      options = Bosh::Cli::Client::Uaa::Options.parse(
        {ca_cert: 'some-ca-cert-file'},
        {'url' => 'https://example.com'},
        {'BOSH_CLIENT' => 'some-client', 'BOSH_CLIENT_SECRET' => 'some-client-secret'})
      expect(options).to eq(Bosh::Cli::Client::Uaa::Options.new(
            'https://example.com',
            'some-ca-cert-file',
            'some-client',
            'some-client-secret'))
    end


    it 'fails when url is not https' do
      expect do
        Bosh::Cli::Client::Uaa::Options.parse({}, { 'url' => 'http://example.com' }, {})
      end.to raise_error Bosh::Cli::Client::Uaa::Options::ValidationError, "HTTPS protocol is required"
    end
  end

  describe "#client_auth?" do
    it "is true if both client id and secret are set" do
      options_with_id_and_secret = Bosh::Cli::Client::Uaa::Options.new('https://example.com', 'some-ca-cert-file', 'some-client', 'some-client-secret')
      options_without_id = Bosh::Cli::Client::Uaa::Options.new('https://example.com', 'some-ca-cert-file', nil, 'some-client-secret')
      options_without_secret = Bosh::Cli::Client::Uaa::Options.new('https://example.com', 'some-ca-cert-file', 'some-client', nil)
      options_without_either = Bosh::Cli::Client::Uaa::Options.new('https://example.com', 'some-ca-cert-file', nil, nil)

      expect(options_with_id_and_secret).to be_client_auth
      expect(options_without_id).to_not be_client_auth
      expect(options_without_secret).to_not be_client_auth
      expect(options_without_either).to_not be_client_auth
    end
  end
end
