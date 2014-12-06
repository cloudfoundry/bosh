require 'spec_helper'

describe Bhm::Director do

  # Director client uses event loop and fibers to perform HTTP queries asynchronosuly.
  # However we don't test that here, we only test the synchronous interface.
  # This is way overmocked so it needs an appropriate support from integration tests.

  before :each do
    @director = Bhm::Director.new("endpoint" => "foo", "user" => "admin", "password" => "admin")
  end

  it "can fetch deployments from BOSH director" do
    deployments_json = Yajl::Encoder.encode([{ "name" => "a" }, { "name" => "b" }])

    mock_response = double(:response => deployments_json, :response_header => double(:http_status => "200"))
    allow(@director).to receive(:perform_request).with(:get, "/deployments").and_return(mock_response)

    expect(@director.get_deployments).to eq(Yajl::Parser.parse(deployments_json))
  end

  it "raises an error if deployments cannot be fetched" do
    mock_response = double(:response => "foo", :response_header => double(:http_status => "500"), :uri => "deployments_uri")
    allow(@director).to receive(:perform_request).with(:get, "/deployments").and_return(mock_response)

    expect {
      @director.get_deployments
    }.to raise_error(Bhm::DirectorError, "Cannot get deployments from director at deployments_uri: 500 foo")
  end

  it "can fetch deployment by name from BOSH director" do
    deployment_json = Yajl::Encoder.encode(["a" => 1, "b" => 2], ["a" => 3, "b" => 4])
    mock_response = double(:response => deployment_json,  :response_header => double(:http_status => "200"))
    allow(@director).to receive(:perform_request).with(:get, "/deployments/foo/vms").and_return(mock_response)

    expect(@director.get_deployment_vms("foo")).to eq(Yajl::Parser.parse(deployment_json))
  end
end
