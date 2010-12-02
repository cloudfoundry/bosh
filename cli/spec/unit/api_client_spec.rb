require 'spec_helper'

describe Bosh::Cli::ApiClient do

  DUMMY_TARGET = "http://target"

  before do
    @client = Bosh::Cli::ApiClient.new(DUMMY_TARGET, "user", "pass")
  end

  describe "polling jobs" do
    it "polls until success" do
      n_calls = 0
      @client.stub(:get).and_return { n_calls += 1; [ 200, n_calls == 5 ? "done" : "processing" ] }
      
      @client.should_receive(:get).with("/jobs/1").exactly(5).times
      
      @client.poll_job_status("/jobs/1", :poll_interval => 0, :max_polls => 1000).should == :done
    end

    it "respects max polls setting" do
      @client.stub(:get).and_return [ 200, "processing" ]
      @client.should_receive(:get).with("/jobs/1").exactly(10).times
      
      @client.poll_job_status("/jobs/1", :poll_interval => 0, :max_polls => 10).should == :track_timeout
    end

    it "respects poll interval setting" do
      @client.stub(:get).and_return [ 200, "processing" ]

      @client.should_receive(:get).exactly(10).times
      @client.should_receive(:wait).with(5).exactly(9).times.and_return(nil)
      
      @client.poll_job_status("/jobs/1", :poll_interval => 5, :max_polls => 10).should == :track_timeout
    end

    it "stops polling and returns error if status is not HTTP 200" do
      n_calls = 0
      @client.stub(:get).and_return { n_calls += 1; [ n_calls == 5 ? 500 : 200, "processing" ] }

      @client.should_receive(:get).exactly(3).times
      
      @client.poll_job_status("/jobs/1", :poll_interval => 0, :max_polls => 10).should == :track_error
    end

    it "stops polling and returns error if task state is error" do
      @client.stub(:get).and_return { [ 200, "error" ] }

      @client.should_receive(:get).exactly(1).times
      
      @client.poll_job_status("/jobs/1", :poll_interval => 0, :max_polls => 10).should == :track_error
    end    
  end
  
end
