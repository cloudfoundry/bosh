# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "deletes an OpenStack snapshot" do
    snapshot = double("snapshot", :id => "snap-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.snapshots).to receive(:get).with("snap-foobar").and_return(snapshot)
    end

    expect(snapshot).to receive(:status).and_return(:available)
    expect(snapshot).to receive(:destroy).and_return(true)
    expect(cloud).to receive(:wait_resource).with(snapshot, :deleted, :status, true)

    cloud.delete_snapshot("snap-foobar")
  end

  it "doesn't delete an OpenStack snapshot unless its state is `available'" do
    snapshot = double("snapshot", :id => "snap-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.snapshots).to receive(:get).with("snap-foobar").and_return(snapshot)
    end

    expect(snapshot).to receive(:status).and_return(:busy)

    expect {
      cloud.delete_snapshot("snap-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, "Cannot delete snapshot `snap-foobar', state is busy")
  end

end