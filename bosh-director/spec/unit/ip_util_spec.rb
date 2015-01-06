# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::IpUtil do
  include Bosh::Director::IpUtil

  describe "each_ip" do

    before(:each) do
      @obj = Object.new
      @obj.extend(Bosh::Director::IpUtil)
    end

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

    it "should handle an differently formatted range" do
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

  end

end
