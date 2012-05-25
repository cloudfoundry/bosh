# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "rack/test"

describe Bosh::Director::Controller do
  include Rack::Test::Methods

  before(:each) do
    @temp_dir = Dir.mktmpdir
    @blobstore_dir = File.join(@temp_dir, "blobstore")
    FileUtils.mkdir_p(@blobstore_dir)
    FileUtils.mkdir_p(@temp_dir)

    test_config = YAML.load(spec_asset("test-director-config.yml"))
    test_config["dir"] = @temp_dir
    test_config["blobstore"] = {
        "plugin" => "local",
        "properties" => {"blobstore_path" => @blobstore_dir}
    }
    Bosh::Director::Config.configure(test_config)
  end

  after(:each) do
    FileUtils.rm_rf(@temp_dir)
  end

  def app
    @app ||= Bosh::Director::Controller.new
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
    new_task
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
      get "/info"
      last_response.status.should == 200
      Yajl::Parser.parse(last_response.body)["user"].should == nil
    end

    it "authenticated" do
      login_as_admin
      get "/info"

      last_response.status.should == 200
      expected = {
          "name" => "Test Director",
          "version" => "#{Bosh::Director::VERSION} (#{Bosh::Director::Config.revision})",
          "uuid" => Bosh::Director::Config.uuid,
          "user" => "admin",
          "cpi"  => "dummy"
      }

      Yajl::Parser.parse(last_response.body).should == expected
    end

  end

  describe "API calls" do
    before(:each) { login_as_admin }

    describe "creating a stemcell" do
      it "expects compressed stemcell file" do
        post "/stemcells", {}, {"CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz")}
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/stemcells", {}, {"CONTENT_TYPE" => "application/octet-stream", :input => spec_asset("tarball.tgz")}
        last_response.status.should == 404
      end
    end

    describe "creating a release" do
      it "expects compressed release file" do
        post "/releases", {}, {"CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz")}
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/releases", {}, {"CONTENT_TYPE" => "application/octet-stream", :input => spec_asset("tarball.tgz")}
        last_response.status.should == 404
      end
    end

    describe "creating a deployment" do
      it "expects compressed deployment file" do
        post "/deployments", {}, {"CONTENT_TYPE" => "text/yaml", :input => spec_asset("test_conf.yaml")}
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes text/yaml" do
        post "/deployments", {}, {"CONTENT_TYPE" => "text/plain", :input => spec_asset("test_conf.yaml")}
        last_response.status.should == 404
      end
    end

    describe "job management" do
      it "allows putting jobs into different states" do
        Bosh::Director::Models::Deployment.create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        put "/deployments/foo/jobs/nats?state=stopped", {}, {"CONTENT_TYPE" => "text/yaml", :input => spec_asset("test_conf.yaml")}
        expect_redirect_to_queued_task(last_response)
      end

      it "allows putting job instances into different states" do
        Bosh::Director::Models::Deployment.create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        put "/deployments/foo/jobs/dea/2?state=stopped", {}, {"CONTENT_TYPE" => "text/yaml", :input => spec_asset("test_conf.yaml")}
        expect_redirect_to_queued_task(last_response)
      end

      it "doesn't like invalid indices" do
        put "/deployments/foo/jobs/dea/zb?state=stopped", {}, {"CONTENT_TYPE" => "text/yaml", :input => spec_asset("test_conf.yaml")}
        last_response.status.should == 400
      end
    end

    describe "log management" do
      it "allows fetching logs from a particular instance" do
        deployment = Bosh::Director::Models::Deployment.create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        instance = Bosh::Director::Models::Instance.create(:deployment => deployment, :job => "nats", :index => "0", :state => "started")
        get "/deployments/foo/jobs/nats/0/logs", {}
        expect_redirect_to_queued_task(last_response)
      end

      it "404 if no instance" do
        get "/deployments/baz/jobs/nats/0/logs", {}
        last_response.status.should == 404
      end

      it "404 if no deployment" do
        deployment = Bosh::Director::Models::Deployment.create(:name => "bar", :manifest => YAML.dump({"foo" => "bar"}))
        get "/deployments/bar/jobs/nats/0/logs", {}
        last_response.status.should == 404
      end
    end

    describe "listing stemcells" do
      it "has API call that returns a list of stemcells in JSON" do
        stemcells = (1..10).map do |i|
          Bosh::Director::Models::Stemcell.create(:name => "stemcell-#{i}", :version => i, :cid => rand(25000 * i))
        end

        get "/stemcells", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)

        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map { |e| [e["name"], e["version"], e["cid"]] }
        expected_collection = stemcells.sort_by { |e| e.name }.map { |e| [e.name.to_s, e.version.to_s, e.cid.to_s] }

        response_collection.should == expected_collection
      end

      it "returns empty collection if there are no stemcells" do
        get "/stemcells", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.should == []
      end
    end

    describe "listing releases" do
      it "has API call that returns a list of releases in JSON" do
        releases = (1..10).map do |i|
          release = Bosh::Director::Models::Release.create(:name => "release-#{i}")
          (0..rand(3)).each do |v|
            Bosh::Director::Models::ReleaseVersion.create(:release => release, :version => v)
          end
          release
        end

        get "/releases", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map { |e| [e["name"], e["versions"].join(" ")] }
        expected_collection = releases.sort_by { |e| e.name }.map { |e| [e.name.to_s, e.versions.map { |v| v.version.to_s }.join(" ")] }

        response_collection.should == expected_collection
      end

      it "returns empty collection if there are no releases" do
        get "/releases", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.should == []
      end
    end

    describe "listing deployments" do
      it "has API call that returns a list of deployments in JSON" do
        deployments = (1..10).map do |i|
          Bosh::Director::Models::Deployment.create(:name => "deployment-#{i}")
        end

        get "/deployments", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map { |e| [e["name"]] }
        expected_collection = deployments.sort_by { |e| e.name }.map { |e| [e.name.to_s] }

        response_collection.should == expected_collection
      end
    end

    describe "getting deployment info" do
      it "returns manifest" do
        deployment = Bosh::Director::Models::Deployment.create(:name => "test_deployment", :manifest => YAML.dump({"foo" => "bar"}))
        get "/deployments/test_deployment"

        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        YAML.load(body["manifest"]).should == {"foo" => "bar"}
      end
    end

    describe "getting deployment vms info" do
      it "returns a list of agent_ids, jobs and indices" do
        deployment = Bosh::Director::Models::Deployment.create(:name => "test_deployment", :manifest => YAML.dump({"foo" => "bar"}))
        vms = []

        15.times do |i|
          vm_params = {"agent_id" => "agent-#{i}", "cid" => "cid-#{i}", "deployment_id" => deployment.id}
          vm = Bosh::Director::Models::Vm.create(vm_params)

          instance_params = {"deployment_id" => deployment.id, "vm_id" => vm.id, "job" => "job-#{i}", "index" => i, "state" => "started"}
          instance = Bosh::Director::Models::Instance.create(instance_params)
        end

        get "/deployments/test_deployment/vms"

        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        body.should be_kind_of Array
        body.size.should == 15

        15.times do |i|
          body[i].should == {"agent_id" => "agent-#{i}", "job" => "job-#{i}", "index" => i, "cid" => "cid-#{i}"}
        end
      end
    end

    describe "deleting release" do
      it "deletes the whole release" do
        release = Bosh::Director::Models::Release.create(:name => "test_release")
        release.add_version(Bosh::Director::Models::ReleaseVersion.make(:version => "1"))
        release.save

        delete "/releases/test_release"
        expect_redirect_to_queued_task(last_response)
      end

      it "deletes a particular version" do
        release = Bosh::Director::Models::Release.create(:name => "test_release")
        release.add_version(Bosh::Director::Models::ReleaseVersion.make(:version => "1"))
        release.save

        delete "/releases/test_release?version=1"
        expect_redirect_to_queued_task(last_response)
      end
    end

    describe "getting release info" do
      it "returns versions" do
        release = Bosh::Director::Models::Release.create(:name => "test_release")
        (1..10).map do |i|
          release.add_version(Bosh::Director::Models::ReleaseVersion.make(:version => i))
        end
        release.save

        get "/releases/test_release"
        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)

        body["versions"].sort.should == (1..10).map { |i| i.to_s }.sort
      end

      it "returns packages and jobs" do
        pending "TBD"
      end
    end

    describe "listing tasks" do
      it "has API call that returns a list of running tasks" do
        ["queued", "processing", "cancelling", "done"].each do |state|
          (1..20).map { |i| Bosh::Director::Models::Task.make(
              :type => :update_deployment,
              :state => state,
              :timestamp => Time.now.to_i - i) }
        end
        get "/tasks?state=processing"
        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        body.size.should == 20

        get "/tasks?state=processing,cancelling,queued"
        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        body.size.should == 60
      end

      it "has API call that returns a list of recent tasks" do
        ["queued", "processing"].each do |state|
          (1..20).map { |i| Bosh::Director::Models::Task.make(
              :type => :update_deployment,
              :state => state,
              :timestamp => Time.now.to_i - i) }
        end
        get "/tasks?limit=20"
        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        body.size.should == 20
      end
    end

    describe "polling task status" do
      it "has API call that return task status" do
        post "/releases", {}, {"CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz")}
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        get "/tasks/#{new_task_id}"

        last_response.status.should == 200
        task_json = Yajl::Parser.parse(last_response.body)
        task_json["id"].should == 1
        task_json["state"].should == "queued"
        task_json["description"].should == "create release"

        task = Bosh::Director::Models::Task[new_task_id]
        task.state = "processed"
        task.save

        get "/tasks/#{new_task_id}"
        last_response.status.should == 200
        task_json = Yajl::Parser.parse(last_response.body)
        task_json["id"].should == 1
        task_json["state"].should == "processed"
        task_json["description"].should == "create release"
      end

      it "has API call that return task output and task output with ranges" do
        post "/releases", {}, {"CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz")}

        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = File.new(File.join(@temp_dir, "debug"), 'w+')
        output_file.print("Test output")
        output_file.close

        task = Bosh::Director::Models::Task[new_task_id]
        task.output = @temp_dir
        task.save

        get "/tasks/#{new_task_id}/output"
        last_response.status.should == 200
        last_response.body.should == "Test output"
      end

      it "has API call that return task output with ranges" do
        post "/releases", {}, {"CONTENT_TYPE" => "application/x-compressed", :input => spec_asset("tarball.tgz")}
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = File.new(File.join(@temp_dir, "debug"), 'w+')
        output_file.print("Test output")
        output_file.close

        task = Bosh::Director::Models::Task[new_task_id]
        task.output = @temp_dir
        task.save

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
      end

      it "supports returning different types of output (debug, soap, event)" do
        %w(debug event soap).each do |log_type|
          output_file = File.new(File.join(@temp_dir, log_type), 'w+')
          output_file.print("Test output #{log_type}")
          output_file.close
        end

        task = Bosh::Director::Models::Task.new
        task.state = "done"
        task.type = :update_deployment
        task.timestamp = Time.now.to_i
        task.description = "description"
        task.output = @temp_dir
        task.save

        %w(debug event soap).each do |log_type|
          get "/tasks/#{task.id}/output?type=#{log_type}"
          last_response.status.should == 200
          last_response.body.should == "Test output #{log_type}"
        end

        # Default output is debug
        get "/tasks/#{task.id}/output"
        last_response.status.should == 200
        last_response.body.should == "Test output debug"
      end
    end

    describe "resources" do
      it "404 on missing resource" do
        get "/resources/deadbeef"
        last_response.status.should == 404
      end

      it "can fetch resources from blobstore" do
        id = Bosh::Director::Config.blobstore.create("some data")
        get "/resources/#{id}"
        last_response.status.should == 200
        last_response.body.should == "some data"
      end

      it "cleans up temp file after serving it" do
        tmp_file = File.join(Dir.tmpdir, "resource-#{UUIDTools::UUID.random_create}")

        File.open(tmp_file, "w") do |f|
          f.write("some data")
        end

        FileUtils.touch(tmp_file)
        manager = mock("manager")
        Bosh::Director::Api::ResourceManager.stub!(:new).and_return(manager)
        manager.stub!(:get_resource_path).with("deadbeef").and_return(tmp_file)

        File.exists?(tmp_file).should be_true
        get "/resources/deadbeef"
        last_response.body.should == "some data"
        File.exists?(tmp_file).should be_false
      end
    end

    describe "users" do
      it "creates a user" do
        Bosh::Director::Models::User.all.size.should == 0

        user_data = Yajl::Encoder.encode({"username" => "john", "password" => "123"})
        post "/users", {}, {"CONTENT_TYPE" => "application/json", :input => user_data}

        new_user = Bosh::Director::Models::User[:username => "john"]
        new_user.should_not be_nil
        BCrypt::Password.new(new_user.password).should == "123"
      end

      it "doesn't create a user with exising username" do
        user_data = Yajl::Encoder.encode({"username" => "john", "password" => "123"})
        post "/users", {}, {"CONTENT_TYPE" => "application/json", :input => user_data}

        login_as("john", "123")
        post "/users", {}, {"CONTENT_TYPE" => "application/json", :input => user_data}

        last_response.status.should == 400
        Bosh::Director::Models::User.all.size.should == 1
      end

      it "updates user password but not username" do
        user_data = Yajl::Encoder.encode({"username" => "john", "password" => "123"})
        post "/users", {}, {"CONTENT_TYPE" => "application/json", :input => user_data}

        login_as("john", "123")
        new_data = Yajl::Encoder.encode({"username" => "john", "password" => "456"})
        put "/users/john", {}, {"CONTENT_TYPE" => "application/json", :input => new_data}

        last_response.status.should == 204
        user = Bosh::Director::Models::User[:username => "john"]
        BCrypt::Password.new(user.password).should == "456"

        login_as("john", "456")
        change_name = Yajl::Encoder.encode({"username" => "john2", "password" => "123"})
        put "/users/john", {}, {"CONTENT_TYPE" => "application/json", :input => change_name}
        last_response.status.should == 400
        last_response.body.should == "{\"code\":20001,\"description\":\"The username is immutable\"}"
      end

      it "deletes user" do
        user_data = Yajl::Encoder.encode({"username" => "john", "password" => "123"})
        post "/users", {}, {"CONTENT_TYPE" => "application/json", :input => user_data}

        login_as("john", "123")
        delete "/users/john"

        last_response.status.should == 204

        user = Bosh::Director::Models::User[:username => "john"]
        user.should be_nil
      end
    end

    describe "property management" do

      def payload(params)
        {"CONTENT_TYPE" => "application/json", :input => Yajl::Encoder.encode(params)}
      end

      it "REST API for creating, updating, getting and deleting deployment properties" do
        deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")

        get "/deployments/mycloud/properties/foo"
        last_response.status.should == 404

        get "/deployments/othercloud/properties/foo"
        last_response.status.should == 404

        post "/deployments/mycloud/properties", {}, payload(:name => "foo", :value => "bar")
        last_response.status.should == 204

        get "/deployments/mycloud/properties/foo"
        last_response.status.should == 200
        Yajl::Parser.parse(last_response.body)["value"].should == "bar"

        get "/deployments/othercloud/properties/foo"
        last_response.status.should == 404

        put "/deployments/mycloud/properties/foo", {}, payload(:value => "baz")
        last_response.status.should == 204

        get "/deployments/mycloud/properties/foo"
        Yajl::Parser.parse(last_response.body)["value"].should == "baz"

        delete "/deployments/mycloud/properties/foo"
        last_response.status.should == 204

        get "/deployments/mycloud/properties/foo"
        last_response.status.should == 404
      end
    end

    describe "problem management" do

      def payload(params)
        {"CONTENT_TYPE" => "application/json", :input => Yajl::Encoder.encode(params)}
      end

      it "exposes problem managent REST API" do
        deployment = Bosh::Director::Models::Deployment.make(:name => "mycloud")

        get "/deployments/mycloud/problems"
        last_response.status.should == 200
        Yajl::Parser.parse(last_response.body).should == []

        post "/deployments/mycloud/scans"
        expect_redirect_to_queued_task(last_response)

        put "/deployments/mycloud/problems", payload(:solutions => {42 => "do_this", 43 => "do_that", 44 => nil})
        last_response.status.should == 404

        problem = Bosh::Director::Models::DeploymentProblem.
            create(:deployment_id => deployment.id, :resource_id => 2, :type => "test", :state => "open", :data => {})

        put "/deployments/mycloud/problems", {}, payload(:solution => "default")
        expect_redirect_to_queued_task(last_response)
      end
    end

  end

end
