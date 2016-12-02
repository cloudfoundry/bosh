require 'spec_helper'

describe 'UAA client', vcr: {cassette_name: 'uaa-client'} do
  # cassette recorded against a UAA started with:
  #   $ UAA_CONFIG_PATH=~/workspace/bosh/spec/assets ./gradlew run -info
  # add 'record: :all' to the vcr options to re-record
  let(:auth_info) { Bosh::Cli::Client::Uaa::AuthInfo.new(director, {}, 'fake-cert') }
  before { allow(auth_info).to receive(:url).and_return(uaa_url) }
  let(:director) { Bosh::Cli::Client::Director.new(director_url) }
  let(:config) { Bosh::Cli::Config.new(config_file) }
  let(:uaa_url) { 'http://localhost:8080/uaa' }
  let(:director_url) { 'http://localhost:8080' }

  let(:config_file) { Tempfile.new('uaa-integration-spec') }
  after { FileUtils.rm_rf(config_file) }

  describe 'login prompts' do
    it 'can fetch the login prompts from uaa' do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(director_url, auth_info, config)
      expect(uaa_client.prompts).to match_array([
            Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
            Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
            Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'One Time Code (Get one at http://localhost:8080/uaa/passcode)'),
          ])
    end
  end

  describe 'logging in' do
    it 'can authenticate and return the token' do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(director_url, auth_info, config)
      access_info = uaa_client.access_info({username: 'marissa', password: 'koala'})
      expect(access_info.username).to eq('marissa')
      expect(access_info.auth_header).to match(/bearer \w+/)
    end

    it "doesn't send empty fields (like passcode) since UAA will attempt to validate them" do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(director_url, auth_info, config)
      access_info = uaa_client.access_info({username: 'marissa', password: 'koala', passcode: ''})
      expect(access_info.username).to eq('marissa')
      expect(access_info.auth_header).to match(/bearer \w+/)
    end
  end
end
