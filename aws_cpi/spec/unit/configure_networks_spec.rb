# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do

  it "doesn't implement `configure_networks'" do
    cloud = make_cloud
    expect {
      cloud.configure_networks("vm-id", {})
    }.to raise_error(Bosh::Clouds::NotImplemented,
                     "`configure_networks' is not implemented " \
                     "by Bosh::AWSCloud::Cloud")
  end

end
