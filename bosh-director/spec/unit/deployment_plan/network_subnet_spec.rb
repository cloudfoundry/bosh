require 'spec_helper'

describe Bosh::Director::DeploymentPlan::NetworkSubnet do
  before { @network = instance_double('Bosh::Director::DeploymentPlan::Network', :name => "net_a") }

  def subnet_spec(properties)
    BD::DeploymentPlan::NetworkSubnet.new(@network, properties)
  end

  describe :initialize do
    it "should create a subnet spec" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"}
      )

      expect(subnet.range.ip).to eq("192.168.0.0")
      subnet.range.ip.size == 255
      expect(subnet.netmask).to eq("255.255.255.0")
      expect(subnet.gateway).to eq("192.168.0.254")
      expect(subnet.dns).to eq(nil)
    end

    it "should require a range" do
      expect {
        subnet_spec(
          "cloud_properties" => {"foo" => "bar"},
          "gateway" => "192.168.0.254",
        )
      }.to raise_error(BD::ValidationMissingField)
    end

    context "gateway property" do
      it "should require a gateway" do
        expect {
          subnet_spec(
            "range" => "192.168.0.0/24",
            "cloud_properties" => {"foo" => "bar"},
          )
        }.to raise_error(BD::ValidationMissingField)
      end

      context "when the gateway is configured to be optional" do
        it "should not require a gateway" do
          allow(Bosh::Director::Config).to receive(:ignore_missing_gateway).and_return(true)

          expect {
            subnet_spec(
              "range" => "192.168.0.0/24",
              "cloud_properties" => {"foo" => "bar"},
            )
          }.to_not raise_error
        end
      end
    end

    it "default cloud properties to empty hash" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "gateway" => "192.168.0.254",
      )
      expect(subnet.cloud_properties).to eq({})
    end

    it "should allow a gateway" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"}
      )

      expect(subnet.gateway.ip).to eq("192.168.0.254")
    end

    it "should make sure gateway is a single ip" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "gateway" => "192.168.0.254/30",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(BD::NetworkInvalidGateway,
                           /must be a single IP/)
    end

    it "should make sure gateway is inside the subnet" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "gateway" => "190.168.0.254",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(BD::NetworkInvalidGateway,
                           /must be inside the range/)
    end

    it "should make sure gateway is not the network id" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "gateway" => "192.168.0.0",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
                           /can't be the network id/)
    end

    it "should make sure gateway is not the broadcast IP" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "gateway" => "192.168.0.255",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(Bosh::Director::NetworkInvalidGateway,
                           /can't be the broadcast IP/)
    end

    it "should allow DNS servers" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "dns" => %w(1.2.3.4 5.6.7.8),
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"}
      )

      expect(subnet.dns).to eq(%w(1.2.3.4 5.6.7.8))
    end

    it "should allow reserved IPs" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24", # 254 IPs
        "reserved" => "192.168.0.5 - 192.168.0.10", # 6 IPs
        "gateway" => "192.168.0.254", # 1 IP
        "cloud_properties" => {"foo" => "bar"}
      )

      expect(subnet.dynamic_ips_count).to eq(254 - 6 - 1)
      expect(subnet.static_ips_count).to eq(0)
    end

    it "should fail when reserved range is not valid" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "reserved" => "192.167.0.5 - 192.168.0.10",
          "gateway" => "192.168.0.254",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(Bosh::Director::NetworkReservedIpOutOfRange,
                           "Reserved IP `192.167.0.5' is out of " +
                           "network `net_a' range")
    end

    it "should allow static IPs" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/24", # 254 IPs
        "static" => "192.168.0.5 - 192.168.0.10", # 6 IPs
        "gateway" => "192.168.0.254", # 1 IP
        "cloud_properties" => {"foo" => "bar"}
      )

      expect(subnet.dynamic_ips_count).to eq(254 - 6 - 1)
      expect(subnet.static_ips_count).to eq(6)
    end

    it "should fail when the static IP is not valid" do
      expect {
        subnet_spec(
          "range" => "192.168.0.0/24",
          "static" => "192.167.0.5 - 192.168.0.10",
          "gateway" => "192.168.0.254",
          "cloud_properties" => {"foo" => "bar"}
        )
      }.to raise_error(Bosh::Director::NetworkStaticIpOutOfRange,
                           "Static IP `192.167.0.5' is out of " +
                           "network `net_a' range")
    end
  end

  describe :overlaps? do
    before(:each) do
      @subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"},
      )
    end

    it "should return false when the given range does not overlap" do
      other = subnet_spec(
        "range" => "192.168.1.0/24",
        "gateway" => "192.168.1.254",
        "cloud_properties" => {"foo" => "bar"},
      )
      expect(@subnet.overlaps?(other)).to eq(false)
    end

    it "should return true when the given range overlaps" do
      other = subnet_spec(
        "range" => "192.168.0.128/28",
        "gateway" => "192.168.0.142",
        "cloud_properties" => {"foo" => "bar"},
      )
      expect(@subnet.overlaps?(other)).to eq(true)
    end
  end

  describe :reserve_ip do
    before(:each) do
      @subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "static" => "192.168.0.5 - 192.168.0.10",
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"}
      )
    end

    it "should reserve dynamic IPs" do
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.1"))).to eq(:dynamic)
    end

    it "should reserve static IPs" do
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.5"))).to eq(:static)
    end

    it "should fail to reserve the IP if it was already reserved" do
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.5"))).to eq(:static)
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.5"))).to eq(nil)
    end
  end

  describe :release_ip do
    before(:each) do
      @subnet = subnet_spec(
        "range" => "192.168.0.0/24",
        "static" => "192.168.0.5 - 192.168.0.10",
        "gateway" => "192.168.0.254",
        "cloud_properties" => {"foo" => "bar"}
      )
    end

    it "should release IPs" do
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.1"))).to eq(:dynamic)
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.1"))).to eq(nil)
      @subnet.release_ip(NetAddr::CIDR.create("192.168.0.1"))
      expect(@subnet.reserve_ip(NetAddr::CIDR.create("192.168.0.1"))).to eq(:dynamic)
    end

    it "should fail if the IP was not in the dynamic or static pools" do
      message = "Can't release IP `192.168.0.0' back to `net_a' network: " +
                "it's' neither in dynamic nor in static pool"
      expect {
        @subnet.release_ip(NetAddr::CIDR.create("192.168.0.0"))
      }.to raise_error(Bosh::Director::NetworkReservationIpNotOwned,
                           message)
    end
  end

  describe :allocate_dynamic_ip do
    it "should allocate an IP from the dynamic pool" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/29",
        "gateway" => "192.168.0.6",
        "cloud_properties" => {"foo" => "bar"}
      )
      ip = subnet.allocate_dynamic_ip
      expect(ip).to eq(NetAddr::CIDR.create("192.168.0.1").to_i)
    end

    # If a pool has many IP addresses, use every IP in the pool rather than
    # rapidly acquiring and releasing the same IP over and over again.
    it "should allocate the least recently released IP from the dynamic pool" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/29",
        "gateway" => "192.168.0.6",
        "cloud_properties" => { "foo" => "bar" },
      )

      allocations = []
      while ip = subnet.allocate_dynamic_ip
        allocations << ip
      end

      # Release allocated IPs in random order
      allocations.shuffle!
      allocations.each do |ip|
        subnet.release_ip(ip)
      end

      # Verify that re-acquiring the released IPs retains order
      allocations.each do |ip|
        expect(subnet.allocate_dynamic_ip).to eq(ip)
      end
    end

    it "should not allocate from the reserved pool" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/29",
        "reserved" => ["192.168.0.1 - 192.168.0.5"],
        "gateway" => "192.168.0.6",
        "cloud_properties" => {"foo" => "bar"}
      )
      expect(subnet.allocate_dynamic_ip).to eq(nil)
    end

    it "should not allocate from the static pool" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/29",
        "static" => ["192.168.0.1 - 192.168.0.5"],
        "gateway" => "192.168.0.6",
        "cloud_properties" => {"foo" => "bar"}
      )
      expect(subnet.allocate_dynamic_ip).to eq(nil)
    end

    it "should return nil if there are no more IPs left to allocate" do
      subnet = subnet_spec(
        "range" => "192.168.0.0/29",
        "gateway" => "192.168.0.6",
        "cloud_properties" => {"foo" => "bar"}
      )
      5.times { expect(subnet.allocate_dynamic_ip).not_to eq(nil) }
      expect(subnet.allocate_dynamic_ip).to eq(nil)
    end
  end
end
