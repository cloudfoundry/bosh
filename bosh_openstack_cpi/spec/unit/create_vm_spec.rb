# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

require "spec_helper"

describe Bosh::OpenStackCloud::Cloud, "create_vm" do

  def agent_settings(unique_name, network_spec = dynamic_network_spec, ephemeral = "/dev/sdb")
    {
      "vm" => {
        "name" => "vm-#{unique_name}"
      },
      "agent_id" => "agent-id",
      "networks" => { "network_a" => network_spec },
      "disks" => {
        "system" => "/dev/sda",
        "ephemeral" => ephemeral,
        "persistent" => {}
      },
      "env" => {
        "test_env" => "value"
      },
      "foo" => "bar", # Agent env
      "baz" => "zaz"
    }
  end

  def openstack_params(network_spec = { "network_a" => dynamic_network_spec} )
    params = {
      name: "vm-#{unique_name}",
      image_ref: "sc-id",
      flavor_ref: "f-test",
      key_name: "test_key",
      security_groups: security_groups,
      os_scheduler_hints: scheduler_hints,
      nics: nics,
      config_drive: false,
      user_data: Yajl::Encoder.encode(user_data(unique_name, network_spec, nameserver, false)),
      availability_zone: "foobar-1a"
    }

    if volume_id
      params[:block_device_mapping] = [{ :volume_size => 2048,
        :volume_id => volume_id,
        :delete_on_termination => "1",
        :device_name => "/dev/vda" }]
    end

    params
  end

  def user_data(unique_name, network_spec, nameserver = nil, openssh = false)
    user_data = {
      "registry" => {
          "endpoint" => "http://registry:3333"
      },
      "server" => {
          "name" => "vm-#{unique_name}"
      }
    }
    user_data["openssh"] = { "public_key" => "public openssh key" } if openssh
    user_data["networks"] = network_spec
    user_data["dns"] = { "nameserver" => [nameserver] } if nameserver
    user_data
  end

  let(:unique_name) { SecureRandom.uuid }
  let(:server) { double("server", :id => "i-test", :name => "i-test") }
  let(:image) { double("image", :id => "sc-id", :name => "sc-id") }
  let(:flavor) { double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :disk => 2, :ephemeral => 2) }
  let(:key_pair) { double("key_pair", :id => "k-test", :name => "test_key",
                   :fingerprint => "00:01:02:03:04", :public_key => "public openssh key") }
  let(:volume_id) { nil }
  let(:security_groups) { %w[default] }
  let(:nameserver) { nil }
  let(:nics) { [] }
  let(:scheduler_hints) { nil }

  before(:each) do
    @registry = mock_registry
  end

  it "creates an OpenStack server and polls until it's ready" do
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:create).with(openstack_params).and_return(server)
      expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
      expect(openstack.images).to receive(:find).and_return(image)
      expect(openstack.flavors).to receive(:find).and_return(flavor)
      expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
      expect(openstack.addresses).to receive(:each).and_yield(address)
    end

    expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
    expect(address).to receive(:server=).with(nil)
    expect(cloud).to receive(:wait_resource).with(server, :active, :state)

    expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name))

    vm_id = cloud.create_vm("agent-id", "sc-id",
                            resource_pool_spec,
                            { "network_a" => dynamic_network_spec },
                            nil, { "test_env" => "value" })
    expect(vm_id).to eq("i-test")
  end

  context "with nameserver" do
    let(:nameserver) { "1.2.3.4" }

    it "passes dns servers in server user data when present" do
      network_spec = dynamic_network_spec
      network_spec["dns"] = [nameserver]
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => "i-test")

      cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(address).to receive(:server=).with(nil)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "with security groups" do
    let(:security_groups) { %w[bar foo] }

    it "creates an OpenStack server with security groups" do
      network_spec = dynamic_network_spec
      network_spec["cloud_properties"] ||= {}
      network_spec["cloud_properties"]["security_groups"] = security_groups
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => nil)

      cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(security_groups)
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "with nic for dynamic network" do
    let(:nics) do
      [
        {"net_id" => "foo"}
      ]
    end

    it "creates an OpenStack server with nic for dynamic network" do
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => nil)
      network_spec = dynamic_network_spec
      network_spec["cloud_properties"] ||= {}
      network_spec["cloud_properties"]["net_id"] = nics[0]["net_id"]

      cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "with nic for manual network" do
    let(:nics) do
      [
        { "net_id" => "foo", "v4_fixed_ip" => "10.0.0.5" }
      ]
    end

    it "creates an OpenStack server with nic for manual network" do
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => nil)
      network_spec = manual_network_spec
      network_spec["ip"] = "10.0.0.5"
      network_spec["cloud_properties"] ||= {}
      network_spec["cloud_properties"]["net_id"] = nics[0]["net_id"]

      cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(unique_name)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  it "associates server with floating ip if vip network is provided" do
    address = double("address", :id => "a-test", :ip => "10.0.0.1",
                     :instance_id => "i-test")

    cloud = mock_cloud do |openstack|
      expect(openstack.servers).to receive(:create).and_return(server)
      expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
      expect(openstack.images).to receive(:find).and_return(image)
      expect(openstack.flavors).to receive(:find).and_return(flavor)
      expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
      expect(openstack.addresses).to receive(:find).and_return(address)
    end

    expect(address).to receive(:server=).with(nil)
    expect(address).to receive(:server=).with(server)
    expect(cloud).to receive(:wait_resource).with(server, :active, :state)

    expect(@registry).to receive(:update_settings)

    cloud.create_vm("agent-id", "sc-id", resource_pool_spec, combined_network_spec)
  end

  context "with scheduler hints" do
    let(:scheduler_hints) do
      {group: 'abcd-foo-bar'}
    end

    it "creates an OpenStack server with scheduler hints" do
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
                      :instance_id => "i-test")

      cloud = mock_cloud do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params(combined_network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:find).and_return(address)
      end

      expect(cloud).to receive(:generate_unique_name).and_return(openstack_params[:name].gsub(/^vm-/,''))
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)
      expect(address).to receive(:server=).exactly(2).times

      expect(@registry).to receive(:update_settings)

      cloud.create_vm("agent-id", "sc-id",
                      resource_pool_spec.merge('scheduler_hints' => scheduler_hints),
                      combined_network_spec)
    end
  end

  context "when boot_from_volume is set" do
    let(:volume_id) { "v-foobar" }
    it "creates an OpenStack server with a boot volume" do
      network_spec = dynamic_network_spec
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => "i-test")

      unique_vol_name = SecureRandom.uuid
      disk_params = {
        :display_name => "volume-#{unique_vol_name}",
        :size => 2,
        :imageRef => "sc-id",
        :availability_zone => "foobar-1a"
      }
      boot_volume = double("volume", :id => "v-foobar")

      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true

      cloud = mock_cloud(cloud_options['properties']) do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.volumes).to receive(:create).with(disk_params).and_return(boot_volume)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).exactly(2).times.and_return(unique_name, unique_vol_name)
      expect(address).to receive(:server=).with(nil)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)
      expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })
      expect(vm_id).to eq("i-test")
    end
  end

  context "when boot_from_volume is set with a volume_type" do
    let(:volume_id) { "v-foobar" }

    it "creates an OpenStack server with a boot volume" do
      network_spec = dynamic_network_spec
      address = double("address", :id => "a-test", :ip => "10.0.0.1",
        :instance_id => "i-test")

      unique_vol_name = SecureRandom.uuid
      disk_params = {
        :display_name => "volume-#{unique_vol_name}",
        :size => 2,
        :imageRef => "sc-id",
        :availability_zone => "foobar-1a",
        :volume_type => "foo"
      }
      boot_volume = double("volume", :id => "v-foobar")

      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true
      cloud_options['properties']['openstack']['boot_volume_cloud_properties'] = {
        "type" => "foo"
      }

      cloud = mock_cloud(cloud_options['properties']) do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params("network_a" => network_spec)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.volumes).to receive(:create).with(disk_params).and_return(boot_volume)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      expect(cloud).to receive(:generate_unique_name).exactly(2).times.and_return(unique_name, unique_vol_name)
      expect(address).to receive(:server=).with(nil)
      expect(cloud).to receive(:wait_resource).with(server, :active, :state)
      expect(cloud).to receive(:wait_resource).with(boot_volume, :available)

      expect(@registry).to receive(:update_settings).
        with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        { "network_a" => network_spec },
        nil, { "test_env" => "value" })

      expect(vm_id).to eq("i-test")
    end
  end

  context "when config_drive option is set" do
    it "creates an OpenStack server with config drive" do
      cloud_options = mock_cloud_options
      cloud_options["properties"]["openstack"]["config_drive"] = 'cdrom'
      address = double("address", id: "a-test", ip: "10.0.0.1", instance_id: nil)
      network_spec = dynamic_network_spec

      cloud = mock_cloud(cloud_options["properties"]) do |openstack|
        expect(openstack.servers).to receive(:create).with(openstack_params.merge(config_drive: true)).and_return(server)
        expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
        expect(openstack.images).to receive(:find).and_return(image)
        expect(openstack.flavors).to receive(:find).and_return(flavor)
        expect(openstack.key_pairs).to receive(:find).and_return(key_pair)
        expect(openstack.addresses).to receive(:each).and_yield(address)
      end

      allow(cloud).to receive(:generate_unique_name).and_return(unique_name)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)

      allow(@registry).to receive(:update_settings).with("i-test", agent_settings(unique_name, network_spec))

      vm_id = cloud.create_vm("agent-id", "sc-id",
        resource_pool_spec,
        {"network_a" => network_spec},
        nil,
        {"test_env" => "value"}
      )

      expect(vm_id).to eq("i-test")
    end
  end

  context "when cannot create an OpenStack server" do
    let(:cloud) do
      mock_cloud do |openstack|
        allow(openstack.servers).to receive(:create).and_return(server)
        allow(openstack.security_groups).to receive(:collect).and_return(%w[default])
        allow(openstack.images).to receive(:find).and_return(image)
        allow(openstack.flavors).to receive(:find).and_return(flavor)
        allow(openstack.key_pairs).to receive(:find).and_return(key_pair)
      end
    end

    it "destroys the server successfully and raises a Retryable Error" do
      allow(server).to receive(:destroy)

      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)

      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(StandardError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end

    it "raises a Retryable Error and logs correct failure message when failed to destroy the server" do
      allow(server).to receive(:destroy)
      allow(cloud).to receive(:wait_resource).with(server, :active, :state).and_raise(Bosh::Clouds::CloudError)
      allow(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect(Bosh::Clouds::Config.logger).to receive(:warn).with('Failed to create server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to receive(:warn).with(/Failed to destroy server:.*/)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          {"network_a" => dynamic_network_spec},
          nil,
          {"test_env" => "value"}
        )
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end
  end

  context "when fail to register an OpenStack server after the server is created" do
    let(:cloud) do
      mock_cloud do |openstack|
        allow(openstack.servers).to receive(:create).and_return(server)
        allow(openstack.security_groups).to receive(:collect).and_return(%w[default])
        allow(openstack.images).to receive(:find).and_return(image)
        allow(openstack.flavors).to receive(:find).and_return(flavor)
        allow(openstack.key_pairs).to receive(:find).and_return(key_pair)
        allow(openstack.addresses).to receive(:each)
      end
    end

    before do
      allow(cloud).to receive(:wait_resource).with(server, :active, :state)
    end

    it "destroys the server successfully and raises a non-retryable Error when CloudError happens" do
      allow(server).to receive(:destroy)

      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          { "network_a" => dynamic_network_spec },
          nil,
          { "test_env" => "value" })
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }

      allow(@registry).to receive(:update_settings).and_raise(StandardError)
      expect(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true)

      expect {
        cloud.create_vm(
          "agent-id",
          "sc-id",
          resource_pool_spec,
          { "network_a" => dynamic_network_spec },
          nil,
          { "test_env" => "value" })
      }.to raise_error { |error|
             expect(error).to be_a(Bosh::Clouds::VMCreationFailed)
             expect(error.ok_to_retry).to eq(false)
           }
    end

    it "logs correct failure message when failed to destroy the server" do
      allow(@registry).to receive(:update_settings).and_raise(Bosh::Clouds::CloudError)
      allow(server).to receive(:destroy)
      allow(cloud).to receive(:wait_resource).with(server, [:terminated, :deleted], :state, true).and_raise(Bosh::Clouds::CloudError)

      expect(Bosh::Clouds::Config.logger).to receive(:warn).with('Failed to register server: Bosh::Clouds::CloudError')
      expect(Bosh::Clouds::Config.logger).to receive(:warn).with(/Failed to destroy server:.*/)

      expect {
        cloud.create_vm(
            "agent-id",
            "sc-id",
            resource_pool_spec,
            { "network_a" => dynamic_network_spec },
            nil,
            { "test_env" => "value" })
      }.to raise_error(Bosh::Clouds::VMCreationFailed)
    end
  end

  it "raises an error when a security group doesn't exist" do
    cloud = mock_cloud do |openstack|
      expect(openstack.security_groups).to receive(:collect).and_return(%w[foo])
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Security group `default' not found")
  end

  it "raises an error when flavor doesn't have enough ephemeral disk capacity" do
    flavor = double("flavor", :id => "f-test", :name => "m1.tiny", :ram => 1024, :ephemeral => 1)
    cloud = mock_cloud do |openstack|
      expect(openstack.security_groups).to receive(:collect).and_return(%w[default])
      expect(openstack.images).to receive(:find).and_return(image)
      expect(openstack.flavors).to receive(:find).and_return(flavor)
    end

    expect {
      cloud.create_vm("agent-id", "sc-id", resource_pool_spec, { "network_a" => dynamic_network_spec },
                      nil, { "test_env" => "value" })
    }.to raise_error(Bosh::Clouds::CloudError, "Flavor `m1.tiny' should have at least 2Gb of ephemeral disk")
  end

  def volume(zone)
    vol = double("volume")
    allow(vol).to receive(:availability_zone).and_return(zone)
    vol
  end

  describe "#select_availability_zone" do
    it "should return nil when all values are nil" do
      cloud = mock_cloud
      expect(cloud.select_availability_zone(nil, nil)).to eq(nil)
    end

    it "should select the resource pool availability_zone when disks are nil" do
      cloud = mock_cloud
      expect(cloud.select_availability_zone(nil, "foobar-1a")).to eq("foobar-1a")
    end

    it "should select the resource pool availability_zone when we are ignoring the disks zone" do
      cloud_options = mock_cloud_options
      cloud_options['properties']['openstack']['boot_from_volume'] = true
      cloud_options['properties']['openstack']['ignore_server_availability_zone'] = true

      cloud = mock_cloud(cloud_options["properties"]) do |openstack|
        allow(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], "foobar-1a")).to eq("foobar-1a")
    end

    it "should select the zone from a list of disks" do
      cloud = mock_cloud do |openstack|
        allow(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], nil)).to eq("foo")
    end

    it "should select the zone from a list of disks and a default" do
      cloud = mock_cloud do |openstack|
        allow(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect(cloud.select_availability_zone(%w[cid1 cid2], "foo")).to eq("foo")
    end
  end

  describe 'failing to select an AZ' do
    it 'should raise an error when the disks are from different zones' do
      cloud = mock_cloud do |openstack|
        expect(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("bar"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], "bar")
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the disk zones are the same and the resource pool AZ is nil" do
      cloud = mock_cloud do |openstack|
        expect(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("bar"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], nil)
      }.to raise_error Bosh::Clouds::CloudError
    end

    it "should raise an error when the zones differ" do
      cloud = mock_cloud do |openstack|
        expect(openstack.volumes).to receive(:get).and_return(volume("foo"), volume("foo"))
      end
      expect {
        cloud.select_availability_zone(%w[cid1 cid2], "baz")
      }.to raise_error Bosh::Clouds::CloudError
    end
  end
end
