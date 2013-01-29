# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::AwsCloud::Cloud do

  it "creates an EC2 volume" do
    disk_params = {
      :size => 2,
      :availability_zone => "us-east-1a"
    }

    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2|
      ec2.volumes.should_receive(:create).with(disk_params).and_return(volume)
    end

    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2048).should == "v-foobar"
  end

  it "rounds up disk size" do
    disk_params = {
      :size => 3,
      :availability_zone => "us-east-1a"
    }

    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2|
      ec2.volumes.should_receive(:create).with(disk_params).and_return(volume)
    end

    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2049)
  end

  it "check min and max disk size" do
    expect {
      mock_cloud.create_disk(100)
    }.to raise_error(Bosh::Clouds::CloudError, /minimum disk size is 1 GiB/)

    expect {
      mock_cloud.create_disk(2000 * 1024)
    }.to raise_error(Bosh::Clouds::CloudError, /maximum disk size is 1 TiB/)
  end

  it "puts disk in the same AZ as an instance" do
    disk_params = {
      :size => 1,
      :availability_zone => "foobar-land"
    }

    instance = double("instance",
                      :id => "i-test",
                      :availability_zone => "foobar-land")

    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2|
      ec2.volumes.should_receive(:create).with(disk_params).and_return(volume)
      ec2.instances.stub(:[]).with("i-test").and_return(instance)
    end

    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, "i-test")
  end

end
