require 'spec_helper'

describe "UAA client", vcr: {cassette_name: 'uaa-client'} do
  # cassette recorded against a UAA started with:
  #   $ UAA_CONFIG_PATH=~/workspace/bosh/spec/assets ./gradlew run -info
  # add 'record: :all' to the vcr options to re-record
  let(:options) { Bosh::Cli::Client::Uaa::Options.new('http://localhost:8080/uaa', 'fake-cert', 'bosh_cli', nil) }

  describe "login prompts" do
    it "can fetch the login prompts from uaa" do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(options)
      expect(uaa_client.prompts).to match_array([
            Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
            Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
            Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'One Time Code (Get one at http://localhost:8080/uaa/passcode)'),
          ])
    end
  end

  describe "logging in" do
    it "can authenticate and return the token" do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(options)
      access_info = uaa_client.login({username: 'marissa', password: 'koala'})
      expect(access_info.username).to eq('marissa')
      expect(access_info.token).to match(/bearer \w+/)
    end

    it "doesn't send empty fields (like passcode) since UAA will attempt to validate them" do
      uaa_client = Bosh::Cli::Client::Uaa::Client.new(options)
      access_info = uaa_client.login({username: 'marissa', password: 'koala', passcode: ''})
      expect(access_info.username).to eq('marissa')
      expect(access_info.token).to match(/bearer \w+/)
    end
  end
end
