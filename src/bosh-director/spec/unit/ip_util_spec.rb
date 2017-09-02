require 'spec_helper'

describe Bosh::Director::IpUtil do
  include Bosh::Director::IpUtil

  before(:each) do
    @obj = Object.new
    @obj.extend(Bosh::Director::IpUtil)
  end

  describe "each_ip" do
    it "should handle single ip" do
      counter = 0
      @obj.each_ip("1.2.3.4") do |ip|
        expect(ip).to eql(NetAddr::CIDR.create("1.2.3.4").to_i)
        counter += 1
      end
      expect(counter).to eq(1)
    end

    it "should handle a range" do
      counter = 0
      @obj.each_ip("1.0.0.0/24") do |ip|
        expect(ip).to eql(NetAddr::CIDR.create("1.0.0.0").to_i + counter)
        counter += 1
      end
      expect(counter).to eq(256)
    end

    it "should handle a differently formatted range" do
      counter = 0
      @obj.each_ip("1.0.0.0 - 1.0.1.0") do |ip|
        expect(ip).to eql(NetAddr::CIDR.create("1.0.0.0").to_i + counter)
        counter += 1
      end
      expect(counter).to eq(257)
    end

    it "should not accept invalid input" do
      expect {@obj.each_ip("1.2.4") {}}.to raise_error
    end

    it "should ignore nil values" do
      counter = 0
      @obj.each_ip(nil) do |ip|
        expect(ip).to eql(NetAddr::CIDR.create("1.2.3.4").to_i)
        counter += 1
      end
      expect(counter).to eq(0)
    end

    context 'when given invalid IP format' do
      it 'should raise NetworkInvalidIpRangeFormat error when given invalid IP range format' do
        range = '192.168.1.2-192.168.1.20,192.168.1.30-192.168.1.40'
        expect{ @obj.each_ip(range) }.to raise_error Bosh::Director::NetworkInvalidIpRangeFormat,
            "Invalid IP range format: #{range}"
      end

      it 'should raise NetAddr::ValidationError' do
        range = '192.168.1.1-192.168.1.1/25'
        expect{ @obj.each_ip(range) {} }.to raise_error Bosh::Director::NetworkInvalidIpRangeFormat,
            "Invalid IP range format: #{range}"
      end
    end
  end

  describe 'format_ip' do
    it 'converts integer to CIDR IP' do
      expect(@obj.format_ip(168427582)).to eq('10.10.0.62')
    end
  end

  describe 'ip_address?' do
    it 'verifies ip address' do
      expect(@obj.ip_address?("127.0.0.1")).to eq(true)
      expect(@obj.ip_address?("2001:0db8:85a3:0000:0000:8a2e:0370:7334")).to eq(true)

      expect(@obj.ip_address?("2001:0db8:85a3:0000:0000:8a2e:0370:7334 ")).to eq(false)
      expect(@obj.ip_address?("255.255.255.256")).to eq(false)
      expect(@obj.ip_address?("999.999.999.999")).to eq(false)
      expect(@obj.ip_address?("dns.com")).to eq(false)
    end
  end
end
