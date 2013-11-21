# Copyright (c) 2009-2013 VMware, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  it "deletes an CloudStack snapshot" do
    snapshot = double("snapshot", :id => "snap-foobar")
    job = generate_job

    cloud = mock_cloud do |compute|
      compute.snapshots.should_receive(:get).with("snap-foobar").and_return(snapshot)
    end

    snapshot.should_receive(:state).and_return('BackedUp')
    snapshot.should_receive(:destroy).and_return(job)
    cloud.should_receive(:wait_job).with(job)

    cloud.delete_snapshot("snap-foobar")
  end

  it "doesn't delete an CloudStack snapshot unless its state is `available'" do
    snapshot = double("snapshot", :id => "snap-foobar")

    cloud = mock_cloud do |compute|
      compute.snapshots.should_receive(:get).with("snap-foobar").and_return(snapshot)
    end

    snapshot.should_receive(:state).and_return('BackingUp')

    expect {
      cloud.delete_snapshot("snap-foobar")
    }.to raise_error(Bosh::Clouds::CloudError, "Cannot delete snapshot `snap-foobar', state is BackingUp")
  end

end
