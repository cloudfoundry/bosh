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
    @temp_dir = Dir.mktmpdir
    FileUtils.mkdir_p(@temp_dir)
    test_config = YAML.load(spec_asset("test-director-config.yml"))
    test_config["dir"] = @temp_dir
    Bosh::Director::Config.configure(test_config)
    redis = Bosh::Director::Config.redis
    redis.select(15)
    redis.flushdb
  end

  after(:each) do
    FileUtils.rm_rf(@temp_dir)
  end

  def app
    @app ||= Bosh::Director::Controller
  end

  def login_as_admin
    basic_authorize "admin", "admin"
  end

  def login_as(username, password)
    basic_authorize username, password
  end

  def expect_redirect_to_queued_task(response)
    response.should be_redirect

    (last_response.location =~ /\/tasks\/(\d+)/).should_not be_nil

    new_task = Bosh::Director::Models::Task[$1]
    new_task.state.should == "queued"
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

  describe "Fetching status" do

    it "not authenticated" do
      get "/status"
      last_response.status.should == 401
    end

    it "authenticated" do
      login_as_admin
      get "/status"

      last_response.status.should == 200
      last_response.body.should == Yajl::Encoder.encode("status" => "Bosh Director (logged in as admin)")
    end

  end  

  describe "API calls" do
    before(:each) { login_as_admin }

    describe "creating a stemcell" do
      it "expects compressed stemcell file" do
        post "/stemcells", {}, { "CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz") }
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/stemcells", {}, { "CONTENT_TYPE" => "application/octet-stream", :input => spec_asset("tarball.tgz") }
        last_response.status.should == 404
      end
    end

    describe "creating a release" do
      it "expects compressed release file" do
        post "/releases", {}, { "CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz") }
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/releases", {}, { "CONTENT_TYPE" => "application/octet-stream", :input => spec_asset("tarball.tgz") }
        last_response.status.should == 404
      end
    end

    describe "creating a deployment" do
      it "expects compressed deployment file" do
        post "/deployments", {}, { "CONTENT_TYPE" => "text/yaml", :input => spec_asset("test_conf.yaml") }
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes text/yaml" do
        post "/deployments", {}, { "CONTENT_TYPE" => "text/plain", :input => spec_asset("test_conf.yaml") }
        last_response.status.should == 404
      end
    end

    describe "polling task status" do
      it "has API call that return task status" do
        post "/releases", {}, { "CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz") }
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        get "/tasks/#{new_task_id}"

        last_response.status.should == 200
        last_response.body.should == "queued"

        task = Bosh::Director::Models::Task[new_task_id]
        task.state = "processed"
        task.save!

        get "/tasks/#{new_task_id}"
        last_response.status.should == 200
        last_response.body.should == "processed"
      end

      it "has API call that return task output and task output with ranges" do
        post "/releases", {}, { "CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz") }
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = Tempfile.new("task_output")
        begin
          output_file.print("Test output")
          output_file.close

          task = Bosh::Director::Models::Task[new_task_id]
          task.output = output_file.path
          task.save!

          get "/tasks/#{new_task_id}/output"
          last_response.status.should == 200
          last_response.body.should == "Test output"
        ensure
          output_file.unlink
        end
      end

      it "has API call that return task output with ranges" do
        post "/releases", {}, { "CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz") }
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = Tempfile.new("task_output")
        begin
          output_file.print("Test output")
          output_file.close

          task = Bosh::Director::Models::Task[new_task_id]
          task.output = output_file.path
          task.save!

          # Range test
          get "/tasks/#{new_task_id}/output", {}, {"HTTP_RANGE" => "bytes=0-3"}
          last_response.status.should == 206
          last_response.body.should == "Test"
          last_response.headers["Content-Length"].should == "4"
          last_response.headers["Content-Range"].should == "bytes 0-3/11"

          # Range test
          get "/tasks/#{new_task_id}/output", {}, {"HTTP_RANGE" => "bytes=5-"}
          last_response.status.should == 206
          last_response.body.should == "output"
          last_response.headers["Content-Length"].should == "6"
          last_response.headers["Content-Range"].should == "bytes 5-10/11"
        ensure
          output_file.unlink
        end
      end
    end

    describe "users" do
      it "creates a user" do
        Bosh::Director::Models::User.all.size.should == 0

        user_data = Yajl::Encoder.encode({ "username" => "john", "password" => "123" })
        post "/users", {}, { "CONTENT_TYPE" => "application/json", :input => user_data }

        new_user = Bosh::Director::Models::User.find(:username => "john").first
        new_user.should_not be_nil
        new_user.password.should == "123"
      end

      it "doesn't create a user with exising username" do
        user_data = Yajl::Encoder.encode({ "username" => "john", "password" => "123" })
        post "/users", {}, { "CONTENT_TYPE" => "application/json", :input => user_data }

        login_as("john", "123")
        post "/users", {}, { "CONTENT_TYPE" => "application/json", :input => user_data }

        last_response.status.should == 400
        Bosh::Director::Models::User.all.size.should == 1
      end

      it "updates user password but not username" do
        user_data = Yajl::Encoder.encode({ "username" => "john", "password" => "123" })
        post "/users", {}, { "CONTENT_TYPE" => "application/json", :input => user_data }

        login_as("john", "123")
        new_data = Yajl::Encoder.encode({ "username" => "john", "password" => "456" })
        put "/users/john", {}, { "CONTENT_TYPE" => "application/json", :input => new_data }

        last_response.status.should == 200
        user = Bosh::Director::Models::User.find(:username => "john").first
        user.password.should == "456"

        login_as("john", "456")
        change_name = Yajl::Encoder.encode({ "username" => "john2", "password" => "123" })
        put "/users/john", {}, { "CONTENT_TYPE" => "application/json", :input => change_name }
        last_response.status.should == 400
        last_response.body.should == "{\"code\":20001,\"description\":\"The username is immutable\"}"
      end

      it "deletes user" do
        user_data = Yajl::Encoder.encode({ "username" => "john", "password" => "123" })
        post "/users", {}, { "CONTENT_TYPE" => "application/json", :input => user_data }

        login_as("john", "123")
        delete "/users/john"

        last_response.status.should == 200

        user = Bosh::Director::Models::User.find(:username => "john").first
        user.should be_nil
      end
    end
  end
  
end
