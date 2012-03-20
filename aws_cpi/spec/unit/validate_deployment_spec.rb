# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  it "doesn't implement `validate_deployment'" do
    cloud = make_cloud
    expect {
      cloud.validate_deployment({}, {})
    }.to raise_error(Bosh::Clouds::NotImplemented,
                     "`validate_deployment' is not implemented "\
                     "by Bosh::AwsCloud::Cloud")
  end

end
