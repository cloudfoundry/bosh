# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::VersionCalc do

  before :each do
    @obj = Object.new.extend(Bosh::Cli::VersionCalc)
  end

  it "can compare versions" do
    @obj.version_cmp("1.2", "1.2").should == 0
    @obj.version_cmp("1.3", "1.2").should == 1
    @obj.version_cmp("0.1.7", "0.9.2").should == -1
    @obj.version_cmp("0.1.7.5", "0.1.7").should == 1
    @obj.version_cmp("0.1.7.4.9.9", "0.1.7.5").should == -1

    @obj.version_cmp("10", "9").should == 1
    @obj.version_cmp("9", "10").should == -1
    @obj.version_cmp("10", "10").should == 0

    @obj.version_cmp(10, 11).should == -1
    @obj.version_cmp(43, 42).should == 1
    @obj.version_cmp(7, 7).should == 0

    @obj.version_cmp("10.9-dev", "10.10-dev").should == -1
    @obj.version_cmp("0.2.3", "0.2.3.0.8").should == -1
    @obj.version_cmp("0.2.3-dev", "0.2.3.0.3-dev").should == -1

    @obj.version_cmp("10.0.at-2013-02-27_21-38-27", "2.0.at-2013-02-26_01-26-46").should == 1
  end

  it 'can compare version correctly when they are timestamps' do
    @obj.version_cmp("2013-02-26_01-26-46", "2013-02-26_01-26-46").should == 0
    @obj.version_cmp("2013-02-26_01-26-46", "2013-02-27_21-38-27").should == -1
    @obj.version_cmp("2013-02-27_21-38-27", "2013-02-26_01-26-46").should == 1
  end

end
