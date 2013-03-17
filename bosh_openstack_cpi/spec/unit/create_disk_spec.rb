# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "creates an OpenStack volume" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :description => "",
      :size => 2
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2048).should == "v-foobar"
  end

  it "rounds up disk size" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :description => "",
      :size => 3
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2049)
  end

  it "check min and max disk size" do
    expect {
      mock_cloud.create_disk(100)
    }.to raise_error(Bosh::Clouds::CloudError, /Minimum disk size is 1 GiB/)

    expect {
      mock_cloud.create_disk(2000 * 1024)
    }.to raise_error(Bosh::Clouds::CloudError, /Maximum disk size is 1 TiB/)
  end

  it "puts disk in the same AZ as a server" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :description => "",
      :size => 1,
      :availability_zone => "foobar-land"
    }
    server = double("server", :id => "i-test",
                    :availability_zone => "foobar-land")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      openstack.servers.should_receive(:get).
        with("i-test").and_return(server)
      openstack.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, "i-test")
  end

end
