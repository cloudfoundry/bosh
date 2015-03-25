# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud do

  it "creates an OpenStack volume" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :display_description => "",
      :size => 2
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

    expect(cloud.create_disk(2048, {})).to eq("v-foobar")
  end

  it "creates an OpenStack volume with a volume_type" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :display_description => "",
      :size => 2,
      :volume_type => "foo"
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

    expect(cloud.create_disk(2048, {"type" => "foo"})).to eq("v-foobar")
  end

  it "creates an OpenStack boot volume" do
    unique_name = SecureRandom.uuid
    stemcell_id = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :size => 2,
      :imageRef => stemcell_id
    }
    boot_volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(boot_volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

    expect(cloud.create_boot_disk(2048, stemcell_id)).to eq("v-foobar")
  end

  it "creates an OpenStack boot volume with an availability_zone" do
    unique_name = SecureRandom.uuid
    stemcell_id = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :size => 2,
      :imageRef => stemcell_id,
      :availability_zone => "foobar-land"
    }
    boot_volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(boot_volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

    expect(cloud.create_boot_disk(2048, stemcell_id, "foobar-land")).to eq("v-foobar")
  end

  it "creates an OpenStack boot volume ignoring the server availability zone" do
    unique_name = SecureRandom.uuid
    stemcell_id = SecureRandom.uuid
    disk_params = {
        :display_name => "volume-#{unique_name}",
        :size => 2,
        :imageRef => stemcell_id
    }
    boot_volume = double("volume", :id => "v-foobar")

    cloud_options = mock_cloud_options
    cloud_options['properties']['openstack']['ignore_server_availability_zone'] = true

    cloud = mock_cloud(cloud_options['properties']) do |openstack|
      expect(openstack.volumes).to receive(:create).with(disk_params).and_return(boot_volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

    expect(cloud.create_boot_disk(2048, stemcell_id, nil)).to eq("v-foobar")
  end

  it "creates an OpenStack boot volume with a volume_type" do
    unique_name = SecureRandom.uuid
    stemcell_id = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :size => 2,
      :imageRef => stemcell_id,
      :volume_type => "foo"
    }
    boot_volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(boot_volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

    expect(cloud.create_boot_disk(2048, stemcell_id, nil, {"type" => "foo"})).to eq("v-foobar")
  end

  it "rounds up disk size" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :display_description => "",
      :size => 3
    }
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(2049, {})
  end

  it "check min disk size" do
    expect {
      mock_cloud.create_disk(100, {})
    }.to raise_error(Bosh::Clouds::CloudError, /Minimum disk size is 1 GiB/)
  end

  it "puts disk in the same AZ as a server" do
    unique_name = SecureRandom.uuid
    disk_params = {
      :display_name => "volume-#{unique_name}",
      :display_description => "",
      :size => 1,
      :availability_zone => "foobar-land"
    }
    server = double("server", :id => "i-test",
                    :availability_zone => "foobar-land")
    volume = double("volume", :id => "v-foobar")

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:get).
        with("i-test").and_return(server)
      expect(openstack.volumes).to receive(:create).
        with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, {}, "i-test")
  end

  it "does not put disk in the same AZ as a server if asked not to" do
    unique_name = SecureRandom.uuid
    disk_params = {
        :display_name => "volume-#{unique_name}",
        :display_description => "",
        :size => 1
    }
    server = double("server", :id => "i-test",
                    :availability_zone => "foobar-land")
    volume = double("volume", :id => "v-foobar")

    cloud_options = mock_cloud_options
    cloud_options['properties']['openstack']['ignore_server_availability_zone'] = true

    cloud = mock_cloud(cloud_options['properties']) do |openstack|
      expect(openstack.volumes).to receive(:create).
          with(disk_params).and_return(volume)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(cloud).to receive(:wait_resource).with(volume, :available)

    cloud.create_disk(1024, {}, "i-test")
  end

end
