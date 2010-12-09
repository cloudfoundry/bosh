require 'spec_helper'

describe Bosh::Cli::DirectorTask do

  before :each do
    @client = Bosh::Cli::ApiClient.new("http://target", "user", "pass")
    @task   = Bosh::Cli::DirectorTask.new(@client, 10)
  end

  it "tracks partial output responses from director" do
    @client.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=0-").
      and_return([206, "test\nout", {"Content-Range" => "bytes 0-7/100"}])

    @client.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=8-").
      and_return([206, "put", {"Content-Range" => "bytes 8-10/100"}])

    @client.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=11-").
      and_return([206, "\nsuccess", {"Content-Range" => "bytes 11-18/100"}])

    @client.stub!(:get).
      with("/tasks/10/output", nil, nil, "Range" => "bytes=19-").
      and_return([416, "", {}])
    
    @task.output.should == "test\n"
    @task.output.should == nil
    @task.output.should == "output\n"
    @task.output.should == nil
    @task.flush_output.should == "success\n"
  end

end
