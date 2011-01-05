require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Util do 

  before(:each) do
    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger
    Bosh::Agent::Config.blobstore_options = {}
    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
    setup_tmp_base_dir
  end

  it "should unpack a blob" do
    response = mock("response")
    response.stub!(:status).and_return(200)
    response.stub!(:content).and_return(dummy_package_data)

    @httpclient.should_receive(:get).with("/resources/some_blobstore_id", {}, {}).and_return(response)

    install_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'packages', 'foo', '2')
    blobstore_id = "some_blobstore_id"
    Bosh::Agent::Util.unpack_blob(blobstore_id, install_dir)
  end

end
