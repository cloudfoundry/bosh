require "spec_helper"

describe Bosh::Cli::Director do

  DUMMY_TARGET = "http://target"

  before do
    @director = Bosh::Cli::Director.new(DUMMY_TARGET, "user", "pass")
  end

  describe "fetching status" do
    it "tells if user is authenticated" do
      @director.should_receive(:get).with("/status", "application/json").and_return([200, JSON.generate("user" => "adam")])
      @director.authenticated?.should == true
    end

    it "tells if user not authenticated" do
      @director.should_receive(:get).with("/status", "application/json").and_return([403, "Forbidden"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/status", "application/json").and_return([500, "Error"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/status", "application/json").and_return([404, "Not Found"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/status", "application/json").and_return([200, JSON.generate("user" => nil, "version" => 1)])
      @director.authenticated?.should == false

      # Backward compatibility
      @director.should_receive(:get).with("/status", "application/json").and_return([200, JSON.generate("status" => "ZB")])
      @director.authenticated?.should == true
    end
  end

  describe "interface REST API" do
    it "has helper methods for HTTP verbs which just blindly delegate to generic request" do
      [:get, :put, :post, :delete].each do |verb|
        @director.should_receive(:request).with(verb, :arg1, :arg2)
        @director.send(verb, :arg1, :arg2)
      end
    end
  end

  describe "API calls" do
    it "creates user" do
      @director.should_receive(:post).with("/users", "application/json", JSON.generate("username" => "joe", "password" => "pass")).and_return(true)
      @director.create_user("joe", "pass")
    end

    it "uploads stemcell" do
      @director.should_receive(:upload_and_track).with("/stemcells", "application/x-compressed", "/path").and_return(true)
      @director.upload_stemcell("/path")
    end

    it "lists stemcells" do
      @director.should_receive(:get).with("/stemcells", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_stemcells
    end

    it "lists releases" do
      @director.should_receive(:get).with("/releases", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_releases
    end

    it "lists deployments" do
      @director.should_receive(:get).with("/deployments", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_deployments
    end

    it "lists currently running tasks" do
      @director.should_receive(:get).with("/tasks?state=processing", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it "lists recent tasks" do
      @director.should_receive(:get).with("/tasks?limit=30", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_recent_tasks

      @director.should_receive(:get).with("/tasks?limit=100", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_recent_tasks(100000)
    end

    it "uploads release" do
      @director.should_receive(:upload_and_track).with("/releases", "application/x-compressed", "/path").and_return(true)
      @director.upload_release("/path")
    end

    it "deletes stemcell" do
      @director.should_receive(:request_and_track).with(:delete, "/stemcells/ubuntu/123", nil, nil).and_return(true)
      @director.delete_stemcell("ubuntu", "123")
    end

    it "deletes deployment" do
      @director.should_receive(:request_and_track).with(:delete, "/deployments/foo", nil, nil).and_return(true)
      @director.delete_deployment("foo")
    end

    it "deletes release (non-force)" do
      @director.should_receive(:request_and_track).with(:delete, "/releases/za", nil, nil).and_return(true)
      @director.delete_release("za")
    end

    it "deletes release (force)" do
      @director.should_receive(:request_and_track).with(:delete, "/releases/zb?force=true", nil, nil).and_return(true)
      @director.delete_release("zb", :force => true)
    end

    it "deploys" do
      @director.should_receive(:upload_and_track).with("/deployments", "text/yaml", "/path").and_return(true)
      @director.deploy("/path")
    end

    it "gets task state" do
      @director.should_receive(:get).with("/tasks/232").and_return([200, JSON.generate({"state" => "done"})])
      @director.get_task_state(232).should == "done"
    end

    it "whines on missing task" do
      @director.should_receive(:get).with("/tasks/232").and_return([404, "Not Found"])
      lambda {
        @director.get_task_state(232).should
      }.should raise_error(Bosh::Cli::MissingTask)
    end

    it "gets task output" do
      @director.should_receive(:get).with("/tasks/232/output", nil, nil, { "Range" => "bytes=42-" }).and_return([206, "test", { :content_range => "bytes 42-56/100" }])
      @director.get_task_output(232, 42).should == ["test", 57]
    end

    it "doesn't set task output new offset if it wasn't a partial response" do
      @director.should_receive(:get).with("/tasks/232/output", nil, nil, { "Range" => "bytes=42-" }).and_return([200, "test"])
      @director.get_task_output(232, 42).should == ["test", nil]
    end

  end

  describe "checking status" do

    it "considers target valid if it responds with 401 (backward compatibility)" do
      @director.stub(:get).with("/status", "application/json").and_return([401, "Not authorized"])
      @director.exists?.should be_true
    end

    it "considers target valid if it responds with 200" do
      @director.stub(:get).with("/status", "application/json").and_return([200, JSON.generate("name" => "Director is your friend")])
      @director.exists?.should be_true
    end

  end

  describe "tracking request" do
    it "starts polling a task if request responded with a redirect to task URL" do
      @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([302, "body", { :location => "/tasks/502" }])
      @director.should_receive(:poll_task).with("502", :arg1 => 1, :arg2 => 2).and_return("polling result")
      @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ "polling result", "body" ]
    end

    it "considers all reponses but 302 a failure" do
      [200, 404, 403].each do |code|
        @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([code, "body", { }])
        @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ :failed, "body" ]
      end
    end

    it "reports task as non trackable if its URL is unfamiliar" do
      @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([302, "body", { :location => "/track-task/502" }])
      @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ :non_trackable, "body" ]
    end

    it "suppports uploading with progress bar" do
      file = spec_asset("valid_release.tgz")
      f = Bosh::Cli::FileWithProgressBar.open(file, "r")

      Bosh::Cli::FileWithProgressBar.stub!(:open).with(file, "r").and_return(f)
      @director.should_receive(:request_and_track).with(:post, "/stuff", "application/x-compressed", f)
      @director.upload_and_track("/stuff", "application/x-compressed", file)
      f.progress_bar.finished?.should be_true
    end
  end

  describe "performing HTTP requests" do
    it "delegates to RestClient" do
      req = {
        :user         => "user",
        :password     => "pass",
        :timeout      => 86400 * 3,
        :open_timeout => 30,
        :url          => "http://target/stuff",
        :headers      => { "Content-Type" => "app/zb", "a" => "b", "c" => "d"}
      }
      RestClient::Request.should_receive(:execute).with(req)
      @director.send(:perform_http_request, req)
    end
  end

  describe "talking to REST API" do
    def req(options = {})
      {
        :user => "user", :password => "pass", :timeout => 86400 * 3, :open_timeout => 30
      }.merge(options)
    end

    it "performs HTTP request" do
      @director.should_receive(:perform_http_request).
        with(req(:method => :get, :url => "http://target/stuff",
                 :payload => "payload", :headers => { "Content-Type" => "app/zb", "h1" => "a", "h2" => "b"}))

      @director.request(:get, "/stuff", "app/zb", "payload", { "h1" => "a", "h2" => "b"})
    end

    it "nicely wraps director error response" do
      [400, 403, 404, 500].each do |code|
        lambda {
          # Familiar JSON
          @director.should_receive(:perform_http_request).and_return([code, JSON.generate("code" => "40422", "description" => "Weird stuff happened"), { }])
          @director.request(:get, "/stuff", "application/octet-stream", "payload", { :hdr1 => "a", :hdr2 => "b"})
        }.should raise_error(Bosh::Cli::DirectorError, "Director error 40422: Weird stuff happened")

        lambda {
          # Not JSON
          @director.should_receive(:perform_http_request).and_return([code, "error message goes here", { }])
          @director.request(:get, "/stuff", "application/octet-stream", "payload", { :hdr1 => "a", :hdr2 => "b"})
        }.should raise_error(Bosh::Cli::DirectorError, "Director error (HTTP #{code}): error message goes here")

        lambda {
          # JSON but weird
          @director.should_receive(:perform_http_request).and_return([code, JSON.generate("a" => "b", "c" => "d"), { }])
          @director.request(:get, "/stuff", "application/octet-stream", "payload", { :hdr1 => "a", :hdr2 => "b"})
        }.should raise_error(Bosh::Cli::DirectorError, %Q[Director error (HTTP #{code}): {"a":"b","c":"d"}])
      end
    end

    it "wraps director access exceptions" do
      [URI::Error, SocketError, Errno::ECONNREFUSED].each do |err|
        @director.should_receive(:perform_http_request).and_raise(err.new("err message"))
        lambda {
          @director.request(:get, "/stuff", "app/zb", "payload", { })
        }.should raise_error(Bosh::Cli::DirectorInaccessible)
      end
      @director.should_receive(:perform_http_request).and_raise(SystemCallError.new("err message"))
      lambda {
        @director.request(:get, "/stuff", "app/zb", "payload", { })
      }.should raise_error Bosh::Cli::DirectorError
    end
  end

  describe "polling jobs" do
    it "polls until success" do
      n_calls = 0

      @director.should_receive(:get).with("/tasks/1").exactly(5).times.and_return { n_calls += 1; [ 200, JSON.generate("state" => n_calls == 5 ? "done" : "processing") ] }
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(5).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 0, :max_polls => 1000).should == :done
    end

    it "respects max polls setting" do
      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, JSON.generate("state" => "processing") ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 0, :max_polls => 10).should == :track_timeout
    end

    it "respects poll interval setting" do
      @director.stub(:get).and_return [ 200, "processing" ]

      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, JSON.generate("state" => "processing") ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)
      @director.should_receive(:wait).with(5).exactly(9).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 5, :max_polls => 10).should == :track_timeout
    end

    it "stops polling and returns error if status is not HTTP 200" do
      n_calls = 0
      @director.stub(:get).and_return { n_calls += 1; [ n_calls == 5 ? 500 : 200, JSON.generate("state" => "processing") ] }

      @director.should_receive(:get).exactly(3).times
      lambda {
        @director.poll_task(1, :poll_interval => 0, :max_polls => 10)
      }.should raise_error(Bosh::Cli::TaskTrackError, "Got HTTP 500 while tracking task state")
    end

    it "stops polling and returns error if task state is error" do
      @director.stub(:get).and_return { [ 200, JSON.generate("state" => "error") ] }

      @director.should_receive(:get).exactly(1).times

      @director.poll_task(1, :poll_interval => 0, :max_polls => 10).should == :error
    end
  end

end
