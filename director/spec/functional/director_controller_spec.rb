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
    BD::Config.configure(test_config)
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

    new_task = BD::Models::Task[$1]
    new_task.state.should == "queued"
    new_task
  end

  def payload(content_type, params)
    {"CONTENT_TYPE" => content_type.to_s,
     :input => Yajl::Encoder.encode(params)}
  end

  it "requires auth" do
    get "/"
    last_response.status.should == 401
  end

  it "allows Basic HTTP Auth with admin/admin credentials for " +
     "test purposes (even though user doesn't exist)" do
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
          "version" => "#{BD::VERSION} (#{BD::Config.revision})",
          "uuid" => BD::Config.uuid,
          "user" => "admin",
          "cpi"  => "dummy",
          "features" => {"dns" => false}
      }

      Yajl::Parser.parse(last_response.body).should == expected
    end
  end

  describe "API calls" do
    before(:each) { login_as_admin }

    describe "creating a stemcell" do
      it "expects compressed stemcell file" do
        post "/stemcells", {},
            payload("application/x-compressed", spec_asset("tarball.tgz"))
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/stemcells", {},
            payload("application/octet-stream", spec_asset("tarball.tgz"))
        last_response.status.should == 404
      end
    end

    describe "creating a release" do
      it "expects compressed release file" do
        post "/releases", {},
            payload("application/x-compressed", spec_asset("tarball.tgz"))
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes application/x-compressed" do
        post "/releases", {},
            payload("application/octet-stream", spec_asset("tarball.tgz"))
        last_response.status.should == 404
      end
    end

    describe "creating a deployment" do
      it "expects compressed deployment file" do
        post "/deployments", {},
            payload("text/yaml", spec_asset("test_conf.yaml"))
        expect_redirect_to_queued_task(last_response)
      end

      it "only consumes text/yaml" do
        post "/deployments", {},
            payload("text/plain", spec_asset("test_conf.yaml"))
        last_response.status.should == 404
      end
    end

    describe "job management" do
      it "allows putting jobs into different states" do
        BD::Models::Deployment.
            create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        put "/deployments/foo/jobs/nats?state=stopped", {},
            payload("text/yaml", spec_asset("test_conf.yaml"))
        expect_redirect_to_queued_task(last_response)
      end

      it "allows putting job instances into different states" do
        BD::Models::Deployment.
            create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        put "/deployments/foo/jobs/dea/2?state=stopped", {},
            payload("text/yaml", spec_asset("test_conf.yaml"))
        expect_redirect_to_queued_task(last_response)
      end

      it "doesn't like invalid indices" do
        put "/deployments/foo/jobs/dea/zb?state=stopped", {},
            payload("text/yaml", spec_asset("test_conf.yaml"))
        last_response.status.should == 400
      end
    end

    describe "log management" do
      it "allows fetching logs from a particular instance" do
        deployment = BD::Models::Deployment.
            create(:name => "foo", :manifest => YAML.dump({"foo" => "bar"}))
        instance = BD::Models::Instance.
            create(:deployment => deployment, :job => "nats",
                   :index => "0", :state => "started")
        get "/deployments/foo/jobs/nats/0/logs", {}
        expect_redirect_to_queued_task(last_response)
      end

      it "404 if no instance" do
        get "/deployments/baz/jobs/nats/0/logs", {}
        last_response.status.should == 404
      end

      it "404 if no deployment" do
        deployment = BD::Models::Deployment.
            create(:name => "bar", :manifest => YAML.dump({"foo" => "bar"}))
        get "/deployments/bar/jobs/nats/0/logs", {}
        last_response.status.should == 404
      end
    end

    describe "listing stemcells" do
      it "has API call that returns a list of stemcells in JSON" do
        stemcells = (1..10).map do |i|
          BD::Models::Stemcell.
              create(:name => "stemcell-#{i}", :version => i,
                     :cid => rand(25000 * i))
        end

        get "/stemcells", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)

        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map do |e|
          [e["name"], e["version"], e["cid"]]
        end

        expected_collection = stemcells.sort_by { |e| e.name }.map do |e|
          [e.name.to_s, e.version.to_s, e.cid.to_s]
        end

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
          release = BD::Models::Release.create(:name => "release-#{i}")
          (0..rand(3)).each do |v|
            BD::Models::ReleaseVersion.
                create(:release => release, :version => v)
          end
          d = BD::Models::Deployment.create(:name => "deployment-#{i}")
          d.add_release_version(release.versions.sample)
          release
        end

        get "/releases", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map do |e|
          [e["name"], e["versions"].join(" "), e["in_use"].join(" ")]
        end

        expected_collection = releases.sort_by { |e| e.name }.map do |e|
          [e.name.to_s,
           e.versions.map { |v| v.version.to_s }.join(" "),
           e.versions_dataset.order_by(:version.asc).reject { |rv|
             rv.deployments.empty?
           }.map { |rv| rv.version }.join(" ")
          ]
        end

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
          BD::Models::Deployment.create(:name => "deployment-#{i}")
        end

        get "/deployments", {}, {}
        last_response.status.should == 200

        body = Yajl::Parser.parse(last_response.body)
        body.kind_of?(Array).should be_true
        body.size.should == 10

        response_collection = body.map { |e| [e["name"]] }
        expected_collection = deployments.sort_by { |e| e.name }.map do |e|
          [e.name.to_s]
        end

        response_collection.should == expected_collection
      end
    end

    describe "getting deployment info" do
      it "returns manifest" do
        deployment = BD::Models::Deployment.
            create(:name => "test_deployment",
                   :manifest => YAML.dump({"foo" => "bar"}))
        get "/deployments/test_deployment"

        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        YAML.load(body["manifest"]).should == {"foo" => "bar"}
      end
    end

    describe "getting deployment vms info" do
      it "returns a list of agent_ids, jobs and indices" do
        deployment = BD::Models::Deployment.
            create(:name => "test_deployment",
                   :manifest => YAML.dump({"foo" => "bar"}))
        vms = []

        15.times do |i|
          vm_params = {
            "agent_id" => "agent-#{i}",
            "cid" => "cid-#{i}",
            "deployment_id" => deployment.id
          }
          vm = BD::Models::Vm.create(vm_params)

          instance_params = {
            "deployment_id" => deployment.id,
            "vm_id" => vm.id,
            "job" => "job-#{i}",
            "index" => i,
            "state" => "started"
          }
          instance = BD::Models::Instance.create(instance_params)
        end

        get "/deployments/test_deployment/vms"

        last_response.status.should == 200
        body = Yajl::Parser.parse(last_response.body)
        body.should be_kind_of Array
        body.size.should == 15

        15.times do |i|
          body[i].should == {
            "agent_id" => "agent-#{i}",
            "job" => "job-#{i}",
            "index" => i,
            "cid" => "cid-#{i}"
          }
        end
      end
    end

    describe "deleting release" do
      it "deletes the whole release" do
        release = BD::Models::Release.create(:name => "test_release")
        release.add_version(BD::Models::ReleaseVersion.make(:version => "1"))
        release.save

        delete "/releases/test_release"
        expect_redirect_to_queued_task(last_response)
      end

      it "deletes a particular version" do
        release = BD::Models::Release.create(:name => "test_release")
        release.add_version(BD::Models::ReleaseVersion.make(:version => "1"))
        release.save

        delete "/releases/test_release?version=1"
        expect_redirect_to_queued_task(last_response)
      end
    end

    describe "getting release info" do
      it "returns versions" do
        release = BD::Models::Release.create(:name => "test_release")
        (1..10).map do |i|
          release.add_version(BD::Models::ReleaseVersion.make(:version => i))
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
          (1..20).map { |i| BD::Models::Task.make(
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
          (1..20).map { |i| BD::Models::Task.make(
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
        post "/releases", {},
            payload("application/x-compressed", spec_asset("tarball.tgz"))
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        get "/tasks/#{new_task_id}"

        last_response.status.should == 200
        task_json = Yajl::Parser.parse(last_response.body)
        task_json["id"].should == 1
        task_json["state"].should == "queued"
        task_json["description"].should == "create release"

        task = BD::Models::Task[new_task_id]
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
        post "/releases", {},
            payload("application/x-compressed", spec_asset("tarball.tgz"))

        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = File.new(File.join(@temp_dir, "debug"), 'w+')
        output_file.print("Test output")
        output_file.close

        task = BD::Models::Task[new_task_id]
        task.output = @temp_dir
        task.save

        get "/tasks/#{new_task_id}/output"
        last_response.status.should == 200
        last_response.body.should == "Test output"
      end

      it "has API call that return task output with ranges" do
        post "/releases", {},
            payload("application/x-compressed", spec_asset("tarball.tgz"))
        new_task_id = last_response.location.match(/\/tasks\/(\d+)/)[1]

        output_file = File.new(File.join(@temp_dir, "debug"), 'w+')
        output_file.print("Test output")
        output_file.close

        task = BD::Models::Task[new_task_id]
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

      it "supports returning different types of output (debug, cpi, event)" do
        %w(debug event cpi).each do |log_type|
          output_file = File.new(File.join(@temp_dir, log_type), 'w+')
          output_file.print("Test output #{log_type}")
          output_file.close
        end

        task = BD::Models::Task.new
        task.state = "done"
        task.type = :update_deployment
        task.timestamp = Time.now.to_i
        task.description = "description"
        task.output = @temp_dir
        task.save

        %w(debug event cpi).each do |log_type|
          get "/tasks/#{task.id}/output?type=#{log_type}"
          last_response.status.should == 200
          last_response.body.should == "Test output #{log_type}"
        end

        # Backward compatibility: when log_type=soap return cpi log
        get "/tasks/#{task.id}/output?type=soap"
        last_response.status.should == 200
        last_response.body.should == "Test output cpi"

        # Default output is debug
        get "/tasks/#{task.id}/output"
        last_response.status.should == 200
        last_response.body.should == "Test output debug"
      end

      it "supports returning old soap logs when type = (cpi || soap)" do
        output_file = File.new(File.join(@temp_dir, "soap"), 'w+')
        output_file.print("Test output soap")
        output_file.close

        task = Bosh::Director::Models::Task.new
        task.state = "done"
        task.type = :update_deployment
        task.timestamp = Time.now.to_i
        task.description = "description"
        task.output = @temp_dir
        task.save

        %w(soap cpi).each do |log_type|
          get "/tasks/#{task.id}/output?type=#{log_type}"
          last_response.status.should == 200
          last_response.body.should == "Test output soap"
        end
      end
    end

    describe "resources" do
      it "404 on missing resource" do
        get "/resources/deadbeef"
        last_response.status.should == 404
      end

      it "can fetch resources from blobstore" do
        id = BD::Config.blobstore.create("some data")
        get "/resources/#{id}"
        last_response.status.should == 200
        last_response.body.should == "some data"
      end

      it "cleans up temp file after serving it" do
        tmp_file = File.join(Dir.tmpdir,
            "resource-#{UUIDTools::UUID.random_create}")

        File.open(tmp_file, "w") do |f|
          f.write("some data")
        end

        FileUtils.touch(tmp_file)
        manager = mock("manager")
        BD::Api::ResourceManager.stub!(:new).and_return(manager)
        manager.stub!(:get_resource_path).with("deadbeef").and_return(tmp_file)

        File.exists?(tmp_file).should be_true
        get "/resources/deadbeef"
        last_response.body.should == "some data"
        File.exists?(tmp_file).should be_false
      end
    end

    describe "users" do
      let (:username)  { "john" }
      let (:password)  { "123" }
      let (:user_data) {{"username" => "john", "password" => "123"}}

      it "creates a user" do
        BD::Models::User.all.size.should == 0

        post "/users", {}, payload("application/json", user_data)

        new_user = BD::Models::User[:username => username]
        new_user.should_not be_nil
        BCrypt::Password.new(new_user.password).should == password
      end

      it "doesn't create a user with exising username" do
        post "/users", {}, payload("application/json", user_data)

        login_as(username, password)
        post "/users", {}, payload("application/json", user_data)

        last_response.status.should == 400
        BD::Models::User.all.size.should == 1
      end

      it "updates user password but not username" do
        post "/users", {}, payload("application/json", user_data)

        login_as(username, password)
        new_data = {"username" => username, "password" => "456"}
        put "/users/#{username}", {}, payload("application/json", new_data)

        last_response.status.should == 204
        user = BD::Models::User[:username => username]
        BCrypt::Password.new(user.password).should == "456"

        login_as(username, "456")
        change_name = {"username" => "john2", "password" => password}
        put "/users/#{username}", {}, payload("application/json", change_name)
        last_response.status.should == 400
        last_response.body.should ==
            "{\"code\":20001,\"description\":\"The username is immutable\"}"
      end

      it "deletes user" do
        post "/users", {}, payload("application/json", user_data)

        login_as(username, password)
        delete "/users/#{username}"

        last_response.status.should == 204

        user = BD::Models::User[:username => username]
        user.should be_nil
      end
    end

    describe "property management" do

      it "REST API for creating, updating, getting and deleting " +
         "deployment properties" do

        deployment = BD::Models::Deployment.make(:name => "mycloud")

        get "/deployments/mycloud/properties/foo"
        last_response.status.should == 404

        get "/deployments/othercloud/properties/foo"
        last_response.status.should == 404

        post "/deployments/mycloud/properties", {},
            payload("application/json", {:name => "foo", :value => "bar"})
        last_response.status.should == 204

        get "/deployments/mycloud/properties/foo"
        last_response.status.should == 200
        Yajl::Parser.parse(last_response.body)["value"].should == "bar"

        get "/deployments/othercloud/properties/foo"
        last_response.status.should == 404

        put "/deployments/mycloud/properties/foo", {},
            payload("application/json", :value => "baz")
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

      it "exposes problem managent REST API" do
        deployment = BD::Models::Deployment.make(:name => "mycloud")

        get "/deployments/mycloud/problems"
        last_response.status.should == 200
        Yajl::Parser.parse(last_response.body).should == []

        post "/deployments/mycloud/scans"
        expect_redirect_to_queued_task(last_response)

        put "/deployments/mycloud/problems",
            payload("application/json",
                    :solutions => {42 => "do_this", 43 => "do_that", 44 => nil})
        last_response.status.should == 404

        problem = BD::Models::DeploymentProblem.
            create(:deployment_id => deployment.id, :resource_id => 2,
                   :type => "test", :state => "open", :data => {})

        put "/deployments/mycloud/problems", {},
            payload("application/json", :solution => "default")
        expect_redirect_to_queued_task(last_response)
      end
    end

  end

end
