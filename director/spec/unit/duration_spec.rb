require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::Duration do

  it "should calculate basic duration" do
    Bosh::Director::Duration.duration(0).should == "0 seconds"
    Bosh::Director::Duration.duration(1).should == "1 second"
    Bosh::Director::Duration.duration(1.5).should == "1.5 seconds"
    Bosh::Director::Duration.duration(60).should == "1 minute"
    Bosh::Director::Duration.duration(61).should == "1 minute 1 second"
    Bosh::Director::Duration.duration(2 * 60).should == "2 minutes"
    Bosh::Director::Duration.duration(2 * 60 + 1).should == "2 minutes 1 second"
    Bosh::Director::Duration.duration(60 * 60).should == "1 hour"
    Bosh::Director::Duration.duration(2 * 60 * 60).should == "2 hours"
    Bosh::Director::Duration.duration(2 * 60 * 60 + 60 + 1).should == "2 hours 1 minute 1 second"
    Bosh::Director::Duration.duration(24 * 60 * 60).should == "1 day"
    Bosh::Director::Duration.duration(24 * 60 * 60 + 1).should == "1 day 1 second"
    Bosh::Director::Duration.duration(48 * 60 * 60).should == "2 days"
  end

end
