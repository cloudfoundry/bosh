# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  it "deregisters EC2 image" do
    image = double("image", :id => "i-foo")

    snapshot = double("snapshot")
    snapshot.should_receive(:delete)

    snapshots = double("snapshots")
    snapshots.should_receive(:[]).with("snap-123").and_return(snapshot)

    cloud = mock_cloud do |ec2|
      ec2.images.stub(:[]).with("i-foo").and_return(image)
      ec2.should_receive(:snapshots).and_return(snapshots)
    end

    image.should_receive(:deregister)

    map = { "/dev/sda" => {:snapshot_id => "snap-123"} }
    image.should_receive(:block_device_mappings).and_return(map)

    cloud.delete_stemcell("i-foo")
  end

end
