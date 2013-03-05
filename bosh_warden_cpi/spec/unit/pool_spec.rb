require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::WardenCloud::DevicePool do

  context "initialize" do
    it "should initialize a pool of the right size" do
      pool = Bosh::WardenCloud::DevicePool.new(100)
      pool.size.should == 100
    end

    it "should initialize a pool of size 0 if it is asked to" do
      pool = Bosh::WardenCloud::DevicePool.new(0)
      pool.size.should == 0
    end
  end

  context "acquire" do
    it "should return nil when empty" do
      pool = Bosh::WardenCloud::DevicePool.new(0)
      pool.acquire.should == nil
    end

    it "should return an entry when nonempty" do
      pool = Bosh::WardenCloud::DevicePool.new(1)
      pool.acquire.should == 0
      pool.acquire.should == nil
    end
  end

  context "release" do
    it "should release the entry" do
      pool = Bosh::WardenCloud::DevicePool.new(1)
      pool.acquire.should == 0
      pool.size.should == 0

      pool.release(0)
      pool.size.should == 1

      pool.acquire.should == 0
      pool.size.should == 0
    end
  end

  context "delete_if" do
    it "can delete all odd numbers" do
      pool = Bosh::WardenCloud::DevicePool.new(100)
      pool.size.should == 100

      pool.delete_if { |i| i % 2 != 0 }
      pool.size.should == 50
    end
  end

end
