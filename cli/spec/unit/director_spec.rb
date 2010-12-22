require "spec_helper"

describe Bosh::Cli::Director do

  DUMMY_TARGET = "http://target"

  before do
    @director = Bosh::Cli::Director.new(DUMMY_TARGET, "user", "pass")
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

    it "uploads release" do
      @director.should_receive(:upload_and_track).with("/releases", "application/x-compressed", "/path").and_return(true)
      @director.upload_release("/path")
    end

    it "deploys" do
      @director.should_receive(:upload_and_track).with("/deployments", "text/yaml", "/path").and_return(true)
      @director.deploy("/path")
    end

    it "gets task state" do
      @director.should_receive(:get).with("/tasks/232").and_return([200, "done"])
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

    it "considers target valid if it responds with 401" do
      @director.stub(:get).with("/status").and_return([401, "Not authorized"])
      @director.exists?.should be_true
    end

    it "considers target valid if it responds with 200" do
      @director.stub(:get).with("/status").and_return([200, JSON.generate("status" => "Bosh Director (logged in as admin)")])
      @director.exists?.should be_true
    end

  end

  describe "polling jobs" do
    it "polls until success" do
      n_calls = 0

      @director.should_receive(:get).with("/tasks/1").exactly(5).times.and_return { n_calls += 1; [ 200, n_calls == 5 ? "done" : "processing" ] }
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(5).times.and_return(nil)

      @director.poll_task(1, :poll_interval => 0, :max_polls => 1000).should == :done
    end

    it "respects max polls setting" do
      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, "processing" ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)
      
      @director.poll_task(1, :poll_interval => 0, :max_polls => 10).should == :track_timeout
    end

    it "respects poll interval setting" do
      @director.stub(:get).and_return [ 200, "processing" ]

      @director.should_receive(:get).with("/tasks/1").exactly(10).times.and_return [ 200, "processing" ]
      @director.should_receive(:get).with("/tasks/1/output", nil, nil, "Range" => "bytes=0-").exactly(10).times.and_return(nil)
      @director.should_receive(:wait).with(5).exactly(9).times.and_return(nil)
      
      @director.poll_task(1, :poll_interval => 5, :max_polls => 10).should == :track_timeout
    end

    it "stops polling and returns error if status is not HTTP 200" do
      n_calls = 0
      @director.stub(:get).and_return { n_calls += 1; [ n_calls == 5 ? 500 : 200, "processing" ] }

      @director.should_receive(:get).exactly(3).times
      lambda { 
        @director.poll_task(1, :poll_interval => 0, :max_polls => 10)
      }.should raise_error(Bosh::Cli::TaskTrackError, "Got HTTP 500 while tracking task state")
    end

    it "stops polling and returns error if task state is error" do
      @director.stub(:get).and_return { [ 200, "error" ] }

      @director.should_receive(:get).exactly(1).times
      
      @director.poll_task(1, :poll_interval => 0, :max_polls => 10).should == :error
    end
  end
  
end
