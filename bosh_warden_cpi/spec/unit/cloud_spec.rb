require "spec_helper"

describe Bosh::WardenCloud::Cloud do

  it "can be created using Bosh::Clouds::Provider" do
    cloud = Bosh::Clouds::Provider.create(:warden, cloud_options)
    cloud.should be_an_instance_of(Bosh::Clouds::Warden)
  end

end
