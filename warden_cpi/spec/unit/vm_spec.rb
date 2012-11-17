require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  before :each do
    @cloud = Bosh::Clouds::Provider.create(:warden, {})
  end

  it "can create vm" do
    # @cloud.create_vm('agent_id', 'stemcell_id', nil, {})
  end
end
