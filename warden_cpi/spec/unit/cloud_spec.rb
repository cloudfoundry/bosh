require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::Cloud do

  it "can be created using Bosh::Clouds::Provider" do
    cloud = Bosh::Clouds::Provider.create(:warden, cloud_options)
    cloud.should be_an_instance_of(Bosh::WardenCloud::Cloud)
  end

end
