require 'spec_helper'

describe "UAA client", vcr: { cassette_name: 'uaa-client' } do
  it "can fetch the login prompts from uaa" do
    uaa_client = Bosh::Cli::Client::Uaa.new({'url' => 'http://localhost:8080/uaa'})
    expect(uaa_client.prompts).to match_array([
          Bosh::Cli::Client::Uaa::Prompt.new('username', 'text', 'Email'),
          Bosh::Cli::Client::Uaa::Prompt.new('password', 'password', 'Password'),
          Bosh::Cli::Client::Uaa::Prompt.new('passcode', 'password', 'One Time Code (Get one at http://localhost:8080/uaa/passcode)'),
        ])
  end
end
