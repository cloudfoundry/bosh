# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  it "deletes an EC2 volume" do
    volume = double("volume", :id => "v-foo")

    cloud = mock_cloud do |ec2|
      ec2.volumes.stub(:[]).with("v-foo").and_return(volume)
    end
    cloud.stub(:task_checkpoint)

    volume.should_receive(:state).and_return(:available)
    volume.should_receive(:delete)

    cloud.should_receive(:wait_resource).with(volume, :deleted)

    cloud.delete_disk("v-foo")
  end

  it "doesn't delete volume unless it's state is `available'" do
    volume = double("volume", :id => "v-foo", :state => :busy)

    cloud = mock_cloud do |ec2|
      ec2.volumes.stub(:[]).with("v-foo").and_return(volume)
    end

    expect {
      cloud.delete_disk("v-foo")
    }.to raise_error(Bosh::Clouds::CloudError,
                     "Cannot delete volume `v-foo', state is busy")
  end

  it "does a fast path delete when asked to" do
    volume = double("volume", :id => "v-foo")

    options = mock_cloud_options
    options["aws"]["fast_path_delete"] = "yes"

    cloud = mock_cloud(options) do |ec2|
      ec2.volumes.stub(:[]).with("v-foo").and_return(volume)
    end
    cloud.stub(:task_checkpoint)

    volume.stub(:state => :available)
    volume.should_receive(:delete)

    volume.should_receive(:add_tag).with("Name", {:value => "to be deleted"})
    cloud.should_not_receive(:wait_resource)

    cloud.delete_disk("v-foo")
  end

end
