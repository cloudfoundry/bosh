require "spec_helper"

describe Bosh::Cli::Director do

  DUMMY_TARGET = "http://target"

  before do
    @director = Bosh::Cli::Director.new(DUMMY_TARGET, "user", "pass")
  end

  describe "fetching status" do
    it "tells if user is authenticated" do
      @director.should_receive(:get).with("/info", "application/json").and_return([200, JSON.generate("user" => "adam")])
      @director.authenticated?.should == true
    end

    it "tells if user not authenticated" do
      @director.should_receive(:get).with("/info", "application/json").and_return([403, "Forbidden"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/info", "application/json").and_return([500, "Error"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/info", "application/json").and_return([404, "Not Found"])
      @director.authenticated?.should == false

      @director.should_receive(:get).with("/info", "application/json").and_return([200, JSON.generate("user" => nil, "version" => 1)])
      @director.authenticated?.should == false

      # Backward compatibility
      @director.should_receive(:get).with("/info", "application/json").and_return([200, JSON.generate("status" => "ZB")])
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
      @director.should_receive(:upload_and_track).with("/stemcells", "application/x-compressed", "/path", :log_type=>"event").and_return(true)
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

    it "lists currently running tasks (director version < 0.3.5)" do
      @director.should_receive(:get).with("/info", "application/json").and_return([ 200, JSON.generate({ :version => "0.3.2"})])
      @director.should_receive(:get).with("/tasks?state=processing", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it "lists currently running tasks (director version >= 0.3.5)" do
      @director.should_receive(:get).with("/info", "application/json").and_return([ 200, JSON.generate({ :version => "0.3.5"})])
      @director.should_receive(:get).with("/tasks?state=processing,cancelling,queued", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it "lists recent tasks" do
      @director.should_receive(:get).with("/tasks?limit=30", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_recent_tasks

      @director.should_receive(:get).with("/tasks?limit=100", "application/json").and_return([ 200, JSON.generate([]), {}])
      @director.list_recent_tasks(100000)
    end

    it "uploads release" do
      @director.should_receive(:upload_and_track).with("/releases", "application/x-compressed", "/path", :log_type => "event").and_return(true)
      @director.upload_release("/path")
    end

    it "gets release info" do
      @director.should_receive(:get).with("/releases/foo", "application/json").and_return([200, JSON.generate([]), { }])
      @director.get_release("foo")
    end

    it "gets deployment info" do
      @director.should_receive(:get).with("/deployments/foo", "application/json").and_return([200, JSON.generate([]), { }])
      @director.get_deployment("foo")
    end

    it "deletes stemcell" do
      @director.should_receive(:request_and_track).with(:delete, "/stemcells/ubuntu/123", nil, nil, :log_type => "event").and_return(true)
      @director.delete_stemcell("ubuntu", "123")
    end

    it "deletes deployment" do
      @director.should_receive(:request_and_track).with(:delete, "/deployments/foo", nil, nil, :log_type => "event").and_return(true)
      @director.delete_deployment("foo")
    end

    it "deletes release (non-force)" do
      @director.should_receive(:request_and_track).with(:delete, "/releases/za", nil, nil, :log_type => "event").and_return(true)
      @director.delete_release("za")
    end

    it "deletes release (force)" do
      @director.should_receive(:request_and_track).with(:delete, "/releases/zb?force=true", nil, nil, :log_type => "event").and_return(true)
      @director.delete_release("zb", :force => true)
    end

    it "deploys" do
      @director.should_receive(:request_and_track).with(:post, "/deployments", "text/yaml", "manifest", :log_type => "event").and_return(true)
      @director.deploy("manifest")
    end

    it "changes job state" do
      @director.should_receive(:request_and_track).
        with(:put, "/deployments/foo/jobs/dea?state=stopped", "text/yaml", "manifest", :log_type => "event").and_return(true)
      @director.change_job_state("foo", "manifest", "dea", nil, "stopped")
    end

    it "changes job instance state" do
      @director.should_receive(:request_and_track).
        with(:put, "/deployments/foo/jobs/dea/0?state=detached", "text/yaml", "manifest", :log_type => "event").and_return(true)
      @director.change_job_state("foo", "manifest", "dea", 0, "detached")
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

    it "know how to find time difference with director" do
      now = Time.now
      server_time = now - 100
      Time.stub!(:now).and_return(now)

      @director.should_receive(:get).with("/info").and_return([200, JSON.generate("version" => 1), { :date => server_time.rfc822 }])
      @director.get_time_difference.to_i.should == 100
    end

  end

  describe "checking status" do

    it "considers target valid if it responds with 401 (backward compatibility)" do
      @director.stub(:get).with("/info", "application/json").and_return([401, "Not authorized"])
      @director.exists?.should be_true
    end

    it "considers target valid if it responds with 200" do
      @director.stub(:get).with("/info", "application/json").and_return([200, JSON.generate("name" => "Director is your friend")])
      @director.exists?.should be_true
    end

  end

  describe "tracking request" do
    it "starts polling a task if request responded with a redirect to task URL" do
      @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([302, "body", { :location => "/tasks/502" }])
      @director.should_receive(:poll_task).with("502", :arg1 => 1, :arg2 => 2).and_return("polling result")
      @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ "polling result", "502" ]
    end

    it "considers all reponses but 302 a failure" do
      [200, 404, 403].each do |code|
        @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([code, "body", { }])
        @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ :failed, nil ]
      end
    end

    it "reports task as non trackable if its URL is unfamiliar" do
      @director.should_receive(:request).with(:get, "/stuff", "text/plain", "abc").and_return([302, "body", { :location => "/track-task/502" }])
      @director.request_and_track(:get, "/stuff", "text/plain", "abc", :arg1 => 1, :arg2 => 2).should == [ :non_trackable, nil ]
    end

    it "suppports uploading with progress bar" do
      file = spec_asset("valid_release.tgz")
      f = Bosh::Cli::FileWithProgressBar.open(file, "r")

      Bosh::Cli::FileWithProgressBar.stub!(:open).with(file, "r").and_return(f)
      @director.should_receive(:request_and_track).with(:post, "/stuff", "application/x-compressed", f, { })
      @director.upload_and_track("/stuff", "application/x-compressed", file)
      f.progress_bar.finished?.should be_true
    end
  end

  describe "performing HTTP requests" do
    it "delegates to HTTPClient" do
      headers = { "Content-Type" => "app/zb", "a" => "b", "c" => "d"}
      user = "user"
      password = "pass"
      auth = "Basic " + Base64.encode64("#{user}:#{password}").strip

      client = mock("httpclient")
      client.should_receive(:send_timeout=).with(Bosh::Cli::Director::API_TIMEOUT)
      client.should_receive(:receive_timeout=).with(Bosh::Cli::Director::API_TIMEOUT)
      client.should_receive(:connect_timeout=).with(Bosh::Cli::Director::CONNECT_TIMEOUT)
      HTTPClient.stub!(:new).and_return(client)

      client.should_receive(:request).with(:get, "http://target/stuff", :body => "payload", :header => headers.merge("Authorization" => auth))
      @director.send(:perform_http_request, :get, "http://target/stuff", "payload", headers)
    end
  end

  describe "talking to REST API" do
    it "performs HTTP request" do
      mock_response = mock("response", :code => 200, :body => "test", :headers => {})

      @director.should_receive(:perform_http_request).
        with(:get, "http://target/stuff", "payload", "h1" => "a", "h2" => "b", "Content-Type" => "app/zb").
        and_return(mock_response)

      @director.request(:get, "/stuff", "app/zb", "payload", { "h1" => "a", "h2" => "b"}).should == [200, "test", {}]
    end

    it "nicely wraps director error response" do
      [400, 403, 500].each do |code|
        lambda {
          # Familiar JSON
          mock_response = mock("response", :code => code, :body => JSON.generate("code" => "40422", "description" => "Weird stuff happened"), :headers => {})
          @director.should_receive(:perform_http_request).and_return(mock_response)
          @director.request(:get, "/stuff", "application/octet-stream", "payload", { :hdr1 => "a", :hdr2 => "b"})
        }.should raise_error(Bosh::Cli::DirectorError, "Director error 40422: Weird stuff happened")

        lambda {
          # Not JSON
          mock_response = mock("response", :code => code, :body => "error message goes here", :headers => {})
          @director.should_receive(:perform_http_request).and_return(mock_response)
          @director.request(:get, "/stuff", "application/octet-stream", "payload", { :hdr1 => "a", :hdr2 => "b"})
        }.should raise_error(Bosh::Cli::DirectorError, "Director error (HTTP #{code}): error message goes here")

        lambda {
          # JSON but weird
          mock_response = mock("response", :code => code, :body => JSON.generate("a" => "b", "c" => "d"), :headers => { })
          @director.should_receive(:perform_http_request).and_return(mock_response)
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

    it "streams file" do
      mock_response = mock("response", :code => 200, :body => "test body", :headers => { })
      @director.should_receive(:perform_http_request).and_yield("test body").and_return(mock_response)

      code, filename, headers = @director.request(:get, "/files/foo", nil, nil, { }, { :file => true })

      code.should == 200
      File.read(filename).should == "test body"
      headers.should == { }
    end
  end

  describe "polling jobs" do
    it "polls until success" do
      n_calls = 0

      @director.stub!(:get_time_difference).and_return(0)
      @director.should_receive(:get).with("/tasks/1").exactly(5).times.and_return { n_calls += 1; [ 200, JSON.generate("state" => n_calls == 5 ? "done" : "processing") ] }
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(5).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 0, :max_polls => 1000).should == :done
    end

    it "respects max polls setting" do
      @director.stub!(:get_time_difference).and_return(0)
      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, JSON.generate("state" => "processing") ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 0, :max_polls => 10).should == :track_timeout
    end

    it "respects poll interval setting" do
      @director.stub(:get).and_return [ 200, "processing" ]

      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, JSON.generate("state" => "processing") ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)
      @director.should_receive(:sleep).with(5).exactly(9).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 5, :max_polls => 10).should == :track_timeout
    end

    it "stops polling and returns error if status is not HTTP 200" do
      n_calls = 0
      @director.stub!(:get_time_difference).and_return(0)

      @director.should_receive(:get).with("/tasks/1").and_return { [ 500, JSON.generate("state" => "processing") ] }

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

  it "calls cancel_task on the current task when cancel_current is called" do
    task_num = 1
    @director.stub(:cancel_task).and_return(["body", 200])
    @director.should_receive(:cancel_task).once.with(task_num)
    @director.should_receive(:say).once.with("Cancelling task ##{task_num}.")
    @director.current_running_task = task_num
    @director.cancel_current
  end
end
