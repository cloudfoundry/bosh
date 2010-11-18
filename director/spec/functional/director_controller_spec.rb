require File.dirname(__FILE__) + '/../spec_helper'

require "rack/test"
require "director"

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

describe Bosh::Director::Controller do
  include Rack::Test::Methods

  before(:each) do
    test_config = spec_asset("test-director-config.yml")
    Bosh::Director::Config.configure(YAML.load(test_config))

    redis = Bosh::Director::Config.redis
    redis.select(15)
    redis.flushdb
  end

  def app
    @app ||= Bosh::Director::Controller
  end

  def login_as_admin
    basic_authorize "admin", "admin"
  end

  it "requires auth" do
    get "/"
    last_response.status.should == 401
  end

  it "allows Basic HTTP Auth with admin/admin credentials for test purposes (even though user doesn't exist)" do
    basic_authorize "admin", "admin"
    get "/"
    last_response.status.should == 404
  end

  describe "creating a stemcell" do
    before(:each) { login_as_admin }

    it "expects compressed stemcell file" do
      post "/stemcells", {}, { "CONTENT_TYPE" => "application/x-compressed", "input" => spec_asset("sample_stemcell.tgz") }
      last_response.should be_redirect

      (last_response.location =~ /\/tasks\/(\d+)/).should_not be_nil

      new_task = Bosh::Director::Models::Task[$1]
      new_task.state.should == "queued"
    end

    it "only consumes application/x-compressed" do
      post "/stemcells", {}, { "CONTENT_TYPE" => "application/octet-stream", "input" => spec_asset("sample_stemcell.tgz") }
      last_response.status.should == 404
    end
  end

  
end
