require 'spec_helper'

describe Bosh::Cli::DirectorTask do

  before :each do
    @director = Bosh::Cli::Director.new("http://target", "user", "pass")
  end

  it "tracks partial output responses from director" do
    @task = Bosh::Cli::DirectorTask.new(@director, 10)

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=0-").
      and_return([206, "test\nout", {:content_range => "bytes 0-7/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=8-").
      and_return([206, "put", {:content_range => "bytes 8-10/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=11-").
      and_return([206, " success\n", {:content_range => "bytes 11-19/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=20-").
      and_return([416, "done", {}])

    @task.output.should == "test\n"
    @task.output.should == nil     # No newline yet
    @task.output.should == "output success\n" # Got a newline
    @task.output.should == "done\n" # Flushed
  end

  it "supports explicit output flush" do
    @task = Bosh::Cli::DirectorTask.new(@director, 10)

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=0-").
      and_return([206, "test\nout", {:content_range => "bytes 0-7/100"}])

    @task.output.should == "test\n"
    @task.flush_output.should == "out\n"
    # Nothing in buffer at this point
    @task.flush_output.should == nil
  end
end
