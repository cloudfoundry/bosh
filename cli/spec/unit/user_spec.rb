require 'spec_helper'

describe Bosh::Cli::User do

  describe "creating a user" do

    before do
      @client = Bosh::Cli::ApiClient.new("target", "user", "pass")
      @payload = JSON.generate("username" => "joe", "password" => "secret")      
    end

    it "successfully creates user" do
      @client.should_receive(:post).with("/users", "application/json", @payload).and_return([200, "Created"])
      Bosh::Cli::User.create(@client, "joe", "secret").should == [ true, "User joe has been created"]
    end

    it "handles auth error" do
      @client.should_receive(:post).with("/users", "application/json", @payload).and_return([401, ""])
      Bosh::Cli::User.create(@client, "joe", "secret").should == [ false, "Error 401: Authentication failed"]
    end

    it "handles api call error" do
      error = JSON.generate("code" => 42, "description" => "oops")
      @client.should_receive(:post).with("/users", "application/json", @payload).and_return([500, error])
      Bosh::Cli::User.create(@client, "joe", "secret").should == [ false, "Director error 42: oops"]
    end

    it "handles malformed response" do
      @client.should_receive(:post).with("/users", "application/json", @payload).and_return([500, "bogus response"])
      Bosh::Cli::User.create(@client, "joe", "secret").should == [ false, "Director error: bogus response" ]
    end

    it "handles non-trivial response codes" do
      @client.should_receive(:post).with("/users", "application/json", @payload).and_return([402, "weird"])
      Bosh::Cli::User.create(@client, "joe", "secret").should == [ false, "Director response: 402 weird" ]
    end
    
  end
  
end
