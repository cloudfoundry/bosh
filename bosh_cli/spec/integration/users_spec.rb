require "spec_helper"

describe "User Management" do
  before do
    Bosh::Cli::Config.output = $stdout
  end

  def bosh args
    Bosh::Cli::Runner.run(args.split)
  rescue SystemExit
  end

  let(:username) { "bob" }
  let(:password) { "password4" }

  describe "creating a user" do
    it "sends the request to create a user" do
      body = {username: username, password: password}.to_json

      stub_request(:post, %r{/users}).
        with(body: body).
        to_return(status: 204)

      bosh "-n create user #{username} #{password}"
    end
  end

  describe "deleting a user" do
    it "sends the request to delete a user" do
      stub_request(:delete, %r{/users/#{username}}).to_return(status: 204)

      bosh "-n delete user #{username}"
    end
  end
end
