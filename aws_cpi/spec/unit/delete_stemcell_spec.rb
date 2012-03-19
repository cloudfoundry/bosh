# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AWSCloud::Cloud do

  it "deregisters EC2 image" do
    image = double("image", :id => "i-foo")

    cloud = mock_cloud do |ec2|
      ec2.images.stub(:[]).with("i-foo").and_return(image)
    end

    image.should_receive(:deregister)
    cloud.delete_stemcell("i-foo")
  end

end
