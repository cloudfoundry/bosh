require 'spec_helper'
require 'micro/memory'

describe VCAP::Micro::Memory do
  it "should return nil on a missing memory file" do
    m = VCAP::Micro::Memory.new
    m.previous.should be_nil
  end

  it "should return nil on an invalid memory file" do
    m = VCAP::Micro::Memory.new
    m.load_previous("spec/assets/invalid").should be_nil
  end

  it "should load a valid memory file" do
    m = VCAP::Micro::Memory.new
    m.load_previous("spec/assets/valid").should == 123
  end

  it "should get the current memory" do
    m = VCAP::Micro::Memory.new
    m.stub(:free).and_return("foo  bar\nMem:   123   456\nbar foo\n")
    m.load_current.should == 123
  end

  it "should return nil if it can't get the current memory" do
    m = VCAP::Micro::Memory.new
    m.stub(:free).and_return("")
    m.load_current.should be_nil
  end

  it "should say it hasn't changed when the values are same" do
    m = VCAP::Micro::Memory.new
    m.changed?(123, 123).should be_false
  end

  it "should say it hasn't changed when the values are almost the same" do
    m = VCAP::Micro::Memory.new
    m.changed?(123, 121).should be_false
    m.changed?(123, 125).should be_false
  end

  it "should say it has changed when the values are different" do
    m = VCAP::Micro::Memory.new
    m.changed?(123, 345).should be_true
  end

  it "should say it hasn't changed when one of the values are nil" do
    m = VCAP::Micro::Memory.new
    m.changed?(123, nil).should be_false
  end

  it "should say it hasn't changed when both of the values are nil" do
    m = VCAP::Micro::Memory.new
    m.changed?(nil, nil).should be_false
  end

  it "should update the spec correctly using an even number" do
    m = VCAP::Micro::Memory.new
    max = 2048
    spec = m.update_spec(max, "spec/assets/apply_spec.yml")
    props = spec['properties']
    props['dea']['max_memory'].should == max
    props['cc']['admin_account_capacity']['memory'].should == max
    props['cc']['default_account_capacity']['memory'].should == 1024
  end

  it "should update the spec correctly using an odd number" do
    m = VCAP::Micro::Memory.new
    max = 1001
    spec = m.update_spec(max, "spec/assets/apply_spec.yml")
    props = spec['properties']
    props['dea']['max_memory'].should == max
    props['cc']['admin_account_capacity']['memory'].should == max
    props['cc']['default_account_capacity']['memory'].should == 500
  end

end