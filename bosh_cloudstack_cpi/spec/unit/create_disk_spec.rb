# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::CloudStackCloud::Cloud do

  let(:disk_offerings) do
    [double('disk_offer1', :name => 'disk_offer-100', :id => 'disk_offer1', :disk_size => 100),
     double('disk_offer2', :name => 'disk_offer-30', :id => 'disk_offer2', :disk_size => 30),
     double('disk_offer3', :name => 'disk_offer-40', :id => 'disk_offer3', :disk_size => 40),
     double('disk_offer4', :name => 'disk_offer-1024', :id => 'disk_offer4', :disk_size => 1024)]
  end

  it "creates an CloudStack volume" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :zone_id => mock_cloud_options['cloudstack']['default_zone'],
      :disk_offering_id => disk_offerings[2].id,
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
      compute.stub(:disk_offerings).and_return(disk_offerings)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :allocated)

    cloud.create_disk(39 * 1024).should == "v-foobar"
  end

  it "choose proper disk offering" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :zone_id => mock_cloud_options['cloudstack']['default_zone'],
      :disk_offering_id => disk_offerings[0].id,
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |compute|
      compute.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
      compute.stub(:disk_offerings).and_return(disk_offerings)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :allocated)

    cloud.create_disk(50 * 1024)
  end

  it "check min and max disk size" do
    expect {
      mock_cloud.create_disk(100)
    }.to raise_error(Bosh::Clouds::CloudError, /Minimum disk size is 1 GiB/)

    expect {
      mock_cloud.create_disk(2000 * 1024)
    }.to raise_error(Bosh::Clouds::CloudError, /Maximum disk size is 1 TiB/)
  end

  it "check suitable disk offering exists" do
    expect {
      cloud = mock_cloud do |compute|
        compute.stub(:disk_offerings).and_return([])
    end
    cloud.create_disk(100 * 1024)
    }.to raise_error(Bosh::Clouds::CloudError, /No disk offering found for/)
  end

  it "puts disk in the same AZ as a server" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :name => "volume-#{unique_name}",
      :zone_id => "foobar-land",
      :disk_offering_id => disk_offerings[0].id,
    }
    server = double("server", :id => "i-test",
                    :zone_id => "foobar-land")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |compute|
      compute.servers.should_receive(:get).
        with("i-test").and_return(server)
      compute.volumes.should_receive(:create).
        with(disk_params).and_return(volume)
    end

    cloud.should_receive(:generate_unique_name).and_return(unique_name)
    cloud.should_receive(:wait_resource).with(volume, :allocated)

    cloud.create_disk(1024, "i-test")
  end

end
