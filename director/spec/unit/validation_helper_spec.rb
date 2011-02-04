require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::ValidationHelper do

  before(:each) do
    @helper = Object.new
    @helper.extend(Bosh::Director::ValidationHelper)
  end

  it "should pass if required fields are present" do
    @helper.safe_property({"test" => 1}, "test", :required => true).should eql(1)
  end

  it "should fail if required fields are missing" do
    lambda {
      @helper.safe_property({"testing" => 1}, "test", :required => true)
    }.should raise_exception(Bosh::Director::ValidationMissingField)
  end

  it "should pass if fields match their class" do
    @helper.safe_property({"test" => 1}, "test", :class => Numeric).should eql(1)
  end

  it "should convert numbers to strings when needed" do
    @helper.safe_property({"test" => 1}, "test", :class => String).should eql("1")
  end

  it "should fail if fields don't match their class" do
    lambda {
      @helper.safe_property({"test" => 1}, "test", :class => Array)
    }.should raise_exception(Bosh::Director::ValidationInvalidType)
  end

  it "should pass if numbers don't have constraints" do
    @helper.safe_property({"test" => 1}, "test", :class => Numeric).should eql(1)
  end

  it "should pass if numbers pass min constraints" do
    @helper.safe_property({"test" => 3}, "test", :min => 2).should eql(3)
  end

  it "should pass if numbers pass max constraints" do
    @helper.safe_property({"test" => 3}, "test", :max => 4).should eql(3)
  end

  it "should fail if numbers don't pass min constraints" do
    lambda {
      @helper.safe_property({"test" => 3}, "test", :min => 4).should eql(3)
    }.should raise_exception(Bosh::Director::ValidationViolatedMin)
  end

  it "should fail if numbers don't pass max constraints" do
    lambda {
      @helper.safe_property({"test" => 3}, "test", :max => 2).should eql(3)
    }.should raise_exception(Bosh::Director::ValidationViolatedMax)
  end

end