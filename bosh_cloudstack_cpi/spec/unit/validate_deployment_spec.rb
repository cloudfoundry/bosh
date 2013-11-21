# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "doesn't implement `validate_deployment'" do
    cloud = mock_cloud
    expect {
      cloud.validate_deployment({}, {})
    }.to raise_error(Bosh::Clouds::NotImplemented,
      "`validate_deployment' is not implemented by Bosh::CloudStackCloud::Cloud")
  end

end
