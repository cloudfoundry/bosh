# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../../../spec_helper", __FILE__)

describe VSphereCloud::Resources::Util do
  describe :average_csv do
    it "should compute the average integer value" do
      VSphereCloud::Resources::Util.average_csv("1,2,3").should == 2
    end

    it "should compute the average float value" do
      VSphereCloud::Resources::Util.average_csv("1.5,2.5,3.5").should == 2.5
    end

    it "should return 0 when there is no data" do
      VSphereCloud::Resources::Util.average_csv("").should == 0
    end
  end

  describe :weighted_random do
    it "should calculate the weighted random" do
      util = VSphereCloud::Resources::Util
      util.should_receive(:rand).with(3).and_return(0)
      util.should_receive(:rand).with(3).and_return(1)
      util.should_receive(:rand).with(3).and_return(2)
      util.weighted_random([[:a, 1], [:b, 2]]).should == :a
      util.weighted_random([[:a, 1], [:b, 2]]).should == :b
      util.weighted_random([[:a, 1], [:b, 2]]).should == :b
    end

    it "should return nil when there are no elements" do
      VSphereCloud::Resources::Util.weighted_random([]).should be_nil
    end
  end
end