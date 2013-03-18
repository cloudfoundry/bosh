# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do
  it "should delete the stemcell" do
    stemcell = double(Bosh::AwsCloud::Stemcell)
    Bosh::AwsCloud::Stemcell.stub(:find => stemcell)

    cloud = mock_cloud

    stemcell.should_receive(:delete)

    cloud.delete_stemcell("ami-xxxxxxxx")
  end
end
