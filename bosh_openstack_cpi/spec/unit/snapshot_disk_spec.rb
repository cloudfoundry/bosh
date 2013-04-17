# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "creates an OpenStack snapshot" do
    unique_name = SecureRandom.uuid
    volume = double("volume", :id => "v-foobar")
    snapshot = double("snapshot", :id => "snap-foobar")
    snapshot_params = {
      :name => "snapshot-#{unique_name}",
      :description => "",
      :volume_id => "v-foobar"
    }

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
      openstack.snapshots.should_receive(:create).with(snapshot_params).and_return(snapshot)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(snapshot, :available)

    cloud.snapshot_disk("v-foobar").should == "snap-foobar"
  end

  it "should raise an Exception if OpenStack volume is not found" do
    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(nil)
    end

    expect {
      cloud.snapshot_disk("v-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, "Volume `v-foobar' not found")
  end

end
