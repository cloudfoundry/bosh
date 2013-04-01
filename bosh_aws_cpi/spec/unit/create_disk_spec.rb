# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::AwsCloud::Cloud do

  let(:zones) { [double("us-east-1a", :name => "us-east-1a")] }

  it "creates an EC2 volume" do
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2, region|
      ec2.volumes.should_receive(:create) do |params|
        params[:size].should == 2
        volume
      end
      region.stub(:availability_zones => zones)
    end

    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)

    cloud.create_disk(2048).should == "v-foobar"
  end

  it "creates an EC2 volume with provisioned iops" do
    iops_setting = {
        "provisioned_iops" => 200
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2, region|
      ec2.volumes.should_receive(:create) do |params|
        params[:iops].should == 200
        params[:volume_type].should == "io1"
        volume
      end
      region.stub(:availability_zones => zones)
    end

    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)
    cloud.create_disk( 30 * 1024 , nil, iops_setting)
  end

  it "check min/max provisioned iops and its ratio to disk size" do
    volume = double("volume", :id => "v-foobar")
    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)
    cloud = mock_cloud do |ec2, region|
      region.stub(:availability_zones => zones)
    end
    expect {
      iops_setting = {"provisioned_iops" => 99}
      cloud.create_disk(2000, nil, iops_setting)
    }.to raise_error(Bosh::Clouds::CloudError, /EBS minimal provisioned IOPS is 100/)

    expect {
      iops_setting = {"provisioned_iops" => 10001}
      cloud.create_disk(2000, nil, iops_setting)
    }.to raise_error(Bosh::Clouds::CloudError, /EBS maximal provisioned IOPS is 10000/)

    expect {
      iops_setting = {"provisioned_iops" => 200}
      cloud.create_disk(18000, nil, iops_setting)
    }.to raise_error(Bosh::Clouds::CloudError, /EBS IOPS\/Size ratio is over 10/)
  end

  it "rounds up disk size" do
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2, region|
      ec2.volumes.should_receive(:create) do |params|
        params[:size].should == 3
        volume
      end
      region.stub(:availability_zones => zones)
    end

    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)

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

    cloud = mock_cloud do |ec2, region|
      ec2.volumes.should_receive(:create).with(disk_params).and_return(volume)
      region.stub(:instances => double("instances", :[] =>instance))
    end

    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)

    cloud.create_disk(1024, "i-test")
  end

  it "should pick a random availability zone when no instance is given" do
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |ec2, region|
      ec2.volumes.should_receive(:create) do |params|
        params[:availability_zone].should === "us-east-1a"
        volume
      end
      region.stub(:availability_zones => zones)
    end

    Bosh::AwsCloud::ResourceWait.stub(:for_volume).with(volume: volume, state: :available)

    cloud.create_disk(2048)
  end
end
