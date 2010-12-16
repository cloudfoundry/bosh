require 'spec_helper'

describe Bosh::Cli::DirectorTask do

  before :each do
    @director = Bosh::Cli::Director.new("http://target", "user", "pass")
    @task     = Bosh::Cli::DirectorTask.new(@director, 10)
  end

  it "tracks partial output responses from director" do
    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=0-").
      and_return([206, "test\nout", {:content_range => "bytes 0-7/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=8-").
      and_return([206, "put", {:content_range => "bytes 8-10/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=11-").
      and_return([206, "\nsuccess", {:content_range => "bytes 11-18/100"}])

    @director.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=19-").
      and_return([416, "", {}])
    
    @task.output.should == "test\n"
    @task.output.should == nil
    @task.output.should == "output\n"
    @task.output.should == nil
    @task.flush_output.should == "success\n"
  end

end
