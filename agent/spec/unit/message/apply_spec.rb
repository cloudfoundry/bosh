require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

dummy_package_data = File.open(File.dirname(__FILE__) + '/../../fixtures/dummy.package').read

describe Bosh::Agent::Message::Apply do

  before(:each) do
    Bosh::Agent::Config.base_dir = File.dirname(__FILE__) + "/../../tmp/#{Time.now.to_i}"
    FileUtils.mkdir_p Bosh::Agent::Config.base_dir + '/bosh'

    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger

    Bosh::Agent::Config.blobstore_options = {}
    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  it 'should set deployment in agents state if blank' do
    state = Bosh::Agent::Message::State.new(nil)
    handler = Bosh::Agent::Message::Apply.new([{"deployment" => "foo"}])
    handler.apply
    state.state['deployment'].should == "foo"
  end

  it 'should install packages' do
    response = mock("response")
    response.stub!(:status).and_return(200)
    response.stub!(:content).and_return(dummy_package_data)

    state = Bosh::Agent::Message::State.new(nil)

    apply_data = {
      "deployment" => "foo",
      "packages" => 
        {"bubba" => { "name" => "bubba", "version" => "2", "blobstore_id" => "some_blobstore_id" } 
      },
    }
    @httpclient.should_receive(:get).with("/resources/some_blobstore_id", {}, {}).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_job)
    handler.apply
  end

  it 'should install a job' do
    response = mock("response")
    response.stub!(:status).and_return(200)
    response.stub!(:content).and_return(dummy_package_data)

    state = Bosh::Agent::Message::State.new(nil)

    apply_data = {
      "deployment" => "foo",
      "job" => { "name" => "bubba", 'blobstore_id' => "some_blobstore_id"},
      "release" => { "version" => "99" }
    }
    @httpclient.should_receive(:get).with("/resources/some_blobstore_id", {}, {}).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_packages)
    handler.apply
  end

end

