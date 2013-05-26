# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "creates an OpenStack snapshot" do
    unique_name = SecureRandom.uuid
    volume = double("volume", :id => "v-foobar")
    attachment = { "device" => "/dev/vdc" }
    snapshot = double("snapshot", :id => "snap-foobar")
    snapshot_params = {
      :name => "snapshot-#{unique_name}",
      :description => 'deployment/job/0/vdc',
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

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
      openstack.snapshots.should_receive(:new).with(snapshot_params).and_return(snapshot)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    
    volume.should_receive(:attachments).and_return([attachment])
    
    snapshot.should_receive(:save).with(true)

    cloud.should_receive(:wait_resource).with(snapshot, :available)

    cloud.snapshot_disk("v-foobar", metadata).should == "snap-foobar"
  end

  it "creates an OpenStack snapshot when volume doesn't have any attachment" do
    unique_name = SecureRandom.uuid
    volume = double("volume", :id => "v-foobar")
    snapshot = double("snapshot", :id => "snap-foobar")
    snapshot_params = {
      :name => "snapshot-#{unique_name}",
      :description => 'deployment/job/0',
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

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(volume)
      openstack.snapshots.should_receive(:new).with(snapshot_params).and_return(snapshot)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    
    volume.should_receive(:attachments).and_return([{}])
    
    snapshot.should_receive(:save).with(true)

    cloud.should_receive(:wait_resource).with(snapshot, :available)

    cloud.snapshot_disk("v-foobar", metadata).should == "snap-foobar"
  end
  
  it "should raise an Exception if OpenStack volume is not found" do
    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:get).with("v-foobar").and_return(nil)
    end

    expect {
      cloud.snapshot_disk("v-foobar", {})
    }.to raise_error(Bosh::Clouds::CloudError, "Volume `v-foobar' not found")
  end

end
