require 'spec_helper'

describe Bhm::Director do

  # Director client uses event loop and fibers to perform HTTP queries asynchronosuly.
  # However we don't test that here, we only test the synchronous interface.
  # This is way overmocked so it needs an appropriate support from integration tests.

  before :each do
    @director = Bhm::Director.new("endpoint" => "foo", "user" => "admin", "password" => "admin")
  end

  it "can fetch deployments from Bosh director" do
    deployments_json = Yajl::Encoder.encode([{ "name" => "a" }, { "name" => "b" }])

    mock_response = mock(:response => deployments_json, :response_header => mock(:http_status => "200"))
    @director.stub!(:perform_request).with(:get, "/deployments").and_return(mock_response)

    @director.get_deployments.should == Yajl::Parser.parse(deployments_json)
  end

  it "raises an error if deployments cannot be fetched" do
    mock_response = mock(:response => "foo", :response_header => mock(:http_status => "500"))
    @director.stub!(:perform_request).with(:get, "/deployments").and_return(mock_response)

    lambda {
      @director.get_deployments
    }.should raise_error(Bhm::DirectorError, "Cannot get deployments from director: 500 foo")
  end

  it "can fetch deployment by name from Bosh director" do
    deployment_json = Yajl::Encoder.encode("a" => 1, "b" => 2)
    mock_response = mock(:response => deployment_json,  :response_header => mock(:http_status => "200"))
    @director.stub!(:perform_request).with(:get, "/deployments/foo").and_return(mock_response)

    @director.get_deployment("foo").should == Yajl::Parser.parse(deployment_json)
  end
end
