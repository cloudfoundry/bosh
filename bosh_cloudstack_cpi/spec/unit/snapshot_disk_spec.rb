# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "creates an CloudStack snapshot" do
    volume = double("volume", :id => "v-foobar", :device_id => 3)
    snapshot = double("snapshot", :id => "snap-foobar")
    snapshot_params = {
      :volume_id => "v-foobar",
    }
    metadata = {
      :agent_id => 'agent',
      :instance_id => 'instance',
      :director_name => 'Test Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      :deployment => 'deployment',
      :job => 'job',
      :index => '0'
    }

    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:get).with("v-foobar").and_return(volume)
      compute.snapshots.should_receive(:new).with(snapshot_params).and_return(snapshot)
    end
    Bosh::CloudStackCloud::TagManager.should_receive(:tag).exactly(5).times
    Bosh::CloudStackCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0/sdd')
    snapshot.should_receive(:save).with(true)
    cloud.should_receive(:wait_resource).with(snapshot, :backedup)

    cloud.snapshot_disk("v-foobar", metadata).should == "snap-foobar"
  end

  it "creates an CloudStack snapshot when volume doesn't have any attachment" do
    volume = double("volume", :id => "v-foobar", :device_id => nil)
    snapshot = double("snapshot", :id => "snap-foobar")
    snapshot_params = {
      :volume_id => "v-foobar"
    }
    metadata = {
      :agent_id => 'agent',
      :instance_id => 'instance',
      :director_name => 'Test Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
      :deployment => 'deployment',
      :job => 'job',
      :index => '0'
    }

    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:get).with("v-foobar").and_return(volume)
      compute.snapshots.should_receive(:new).with(snapshot_params).and_return(snapshot)
    end
    Bosh::CloudStackCloud::TagManager.should_receive(:tag).exactly(4).times
    Bosh::CloudStackCloud::TagManager.should_receive(:tag).with(snapshot, 'Name', 'deployment/job/0')
    snapshot.should_receive(:save).with(true)
    cloud.should_receive(:wait_resource).with(snapshot, :backedup)

    cloud.snapshot_disk("v-foobar", metadata).should == "snap-foobar"
  end

  it "should raise an Exception if CloudStack volume is not found" do
    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:get).with("v-foobar").and_return(nil)
    end

    expect {
      cloud.snapshot_disk("v-foobar", {})
    }.to raise_error(Bosh::Clouds::CloudError, "Volume `v-foobar' not found")
  end

end
